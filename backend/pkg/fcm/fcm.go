package fcm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type Client interface {
	SendPush(ctx context.Context, token string, title string, body string, data map[string]string) (string, error)
	SendMulticast(ctx context.Context, tokens []string, title string, body string, data map[string]string) ([]string, error)
}

type fcmClient struct {
	serverKey  string
	projectID  string
	httpClient *http.Client
}

func NewFCMClient(serverKey string, projectID string) Client {
	return &fcmClient{
		serverKey:  serverKey,
		projectID:  projectID,
		httpClient: &http.Client{Timeout: 10 * time.Second},
	}
}

type legacyFCMMessage struct {
	To           string            `json:"to"`
	Notification fcmNotification   `json:"notification"`
	Data         map[string]string `json:"data,omitempty"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
	Sound string `json:"sound"`
}

func (c *fcmClient) SendPush(ctx context.Context, token string, title string, body string, data map[string]string) (string, error) {
	if token == "" {
		return "", fmt.Errorf("recipient FCM token is empty")
	}

	// Simulated / Sandbox fallback if no live FCM key is provided
	if c.serverKey == "" {
		msgID := fmt.Sprintf("sim_fcm_%s", uuid.New().String())
		log.Printf("[FCM SIMULATOR] Push Notification sent to token %s... Title: '%s', Body: '%s', Data: %+v (MessageID: %s)\n",
			token[:min(len(token), 15)], title, body, data, msgID)
		return msgID, nil
	}

	msg := legacyFCMMessage{
		To: token,
		Notification: fcmNotification{
			Title: title,
			Body:  body,
			Sound: "default",
		},
		Data: data,
	}

	bodyBytes, err := json.Marshal(msg)
	if err != nil {
		return "", fmt.Errorf("failed to encode FCM payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://fcm.googleapis.com/fcm/send", bytes.NewBuffer(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create FCM request: %w", err)
	}

	req.Header.Set("Authorization", "key="+c.serverKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to dispatch FCM request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("FCM server responded with status: %d", resp.StatusCode)
	}

	msgID := fmt.Sprintf("fcm_%s", uuid.New().String())
	return msgID, nil
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
