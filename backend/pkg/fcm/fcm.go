package fcm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const messagingScope = "https://www.googleapis.com/auth/firebase.messaging"

// ErrInvalidToken is returned when FCM reports the device token as unregistered
// or malformed; callers should stop sending to it.
var ErrInvalidToken = errors.New("fcm: device token is invalid or unregistered")

type Client interface {
	SendPush(ctx context.Context, token string, title string, body string, data map[string]string) (string, error)
	SendMulticast(ctx context.Context, tokens []string, title string, body string, data map[string]string) ([]string, error)
}

// ServiceAccount mirrors the Firebase service-account JSON key.
type ServiceAccount struct {
	Type                    string `json:"type"`
	ProjectID               string `json:"project_id"`
	PrivateKeyID            string `json:"private_key_id"`
	PrivateKey              string `json:"private_key"`
	ClientEmail             string `json:"client_email"`
	ClientID                string `json:"client_id"`
	AuthURI                 string `json:"auth_uri"`
	TokenURI                string `json:"token_uri"`
	AuthProviderX509CertURL string `json:"auth_provider_x509_cert_url"`
	ClientX509CertURL       string `json:"client_x509_cert_url"`
	UniverseDomain          string `json:"universe_domain"`
}

type fcmClient struct {
	projectID   string
	tokenSource oauth2.TokenSource // nil => simulator mode
	httpClient  *http.Client
}

// NewFCMClient builds an FCM HTTP v1 client. When the service account has no
// private key, the client runs in simulator mode and only logs pushes.
func NewFCMClient(ctx context.Context, sa ServiceAccount) (Client, error) {
	c := &fcmClient{
		projectID:  sa.ProjectID,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
	if sa.PrivateKey == "" {
		log.Println("[FCM] No service account private key configured; running in simulator mode")
		return c, nil
	}
	if sa.ProjectID == "" {
		return nil, errors.New("fcm: project_id is required")
	}
	if sa.Type == "" {
		sa.Type = "service_account"
	}
	// Keys pasted into Consul often carry literal "\n" sequences.
	sa.PrivateKey = strings.ReplaceAll(sa.PrivateKey, "\\n", "\n")

	saJSON, err := json.Marshal(sa)
	if err != nil {
		return nil, fmt.Errorf("fcm: failed to encode service account: %w", err)
	}
	creds, err := google.CredentialsFromJSON(ctx, saJSON, messagingScope)
	if err != nil {
		return nil, fmt.Errorf("fcm: invalid service account credentials: %w", err)
	}
	c.tokenSource = creds.TokenSource
	log.Printf("[FCM] HTTP v1 client initialised for project %s\n", sa.ProjectID)
	return c, nil
}

type v1Payload struct {
	Message v1Message `json:"message"`
}

type v1Message struct {
	Token        string            `json:"token"`
	Notification v1Notification    `json:"notification"`
	Data         map[string]string `json:"data,omitempty"`
	Android      v1Android         `json:"android"`
}

type v1Notification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type v1Android struct {
	Priority     string                `json:"priority"`
	Notification v1AndroidNotification `json:"notification"`
}

type v1AndroidNotification struct {
	Sound       string `json:"sound"`
	ChannelID   string `json:"channel_id"`
	ClickAction string `json:"click_action"`
}

type v1Response struct {
	Name string `json:"name"`
}

func (c *fcmClient) SendPush(ctx context.Context, token string, title string, body string, data map[string]string) (string, error) {
	if token == "" {
		return "", fmt.Errorf("recipient FCM token is empty")
	}

	// Simulated / Sandbox fallback if no live FCM credentials are provided
	if c.tokenSource == nil {
		msgID := fmt.Sprintf("sim_fcm_%s", uuid.New().String())
		log.Printf("[FCM SIMULATOR] Push Notification sent to token %s... Title: '%s', Body: '%s', Data: %+v (MessageID: %s)\n",
			token[:min(len(token), 15)], title, body, data, msgID)
		return msgID, nil
	}

	accessToken, err := c.tokenSource.Token()
	if err != nil {
		return "", fmt.Errorf("failed to obtain FCM access token: %w", err)
	}

	msg := v1Payload{
		Message: v1Message{
			Token:        token,
			Notification: v1Notification{Title: title, Body: body},
			Data:         data,
			Android: v1Android{
				Priority: "high",
				Notification: v1AndroidNotification{
					Sound:       "default",
					ChannelID:   "songothon_default",
					ClickAction: "FLUTTER_NOTIFICATION_CLICK",
				},
			},
		},
	}

	bodyBytes, err := json.Marshal(msg)
	if err != nil {
		return "", fmt.Errorf("failed to encode FCM payload: %w", err)
	}

	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", c.projectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create FCM request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+accessToken.AccessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to dispatch FCM request: %w", err)
	}
	defer resp.Body.Close()

	respBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		if resp.StatusCode == http.StatusNotFound || bytes.Contains(respBytes, []byte("UNREGISTERED")) ||
			(resp.StatusCode == http.StatusBadRequest && bytes.Contains(respBytes, []byte("registration token"))) {
			return "", fmt.Errorf("%w: %s", ErrInvalidToken, string(respBytes))
		}
		return "", fmt.Errorf("FCM server responded with status %d: %s", resp.StatusCode, string(respBytes))
	}

	var out v1Response
	if err := json.Unmarshal(respBytes, &out); err != nil || out.Name == "" {
		return fmt.Sprintf("fcm_%s", uuid.New().String()), nil
	}
	return out.Name, nil
}

func (c *fcmClient) SendMulticast(ctx context.Context, tokens []string, title string, body string, data map[string]string) ([]string, error) {
	var messageIDs []string
	for _, token := range tokens {
		if token == "" {
			continue
		}
		msgID, err := c.SendPush(ctx, token, title, body, data)
		if err != nil {
			log.Printf("[FCM] Failed to deliver push to token: %v\n", err)
			continue
		}
		messageIDs = append(messageIDs, msgID)
	}
	return messageIDs, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
