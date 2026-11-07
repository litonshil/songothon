// Package mailer sends transactional email over SMTP.
package mailer

import (
	"crypto/tls"
	"errors"
	"fmt"
	"mime"
	"net"
	"net/mail"
	"net/smtp"
	"strings"
	"time"
)

// Encryption modes for the SMTP connection.
const (
	EncryptionStartTLS = "starttls" // port 587: plain connect, then upgrade (Gmail, SES, SendGrid, Brevo...)
	EncryptionSSL      = "ssl"      // port 465: TLS from the first byte
	EncryptionNone     = "none"     // local relays / Mailpit / MailHog only
)

// Config holds SMTP server settings.
type Config struct {
	Host       string
	Port       int
	Username   string
	Password   string
	FromEmail  string
	FromName   string
	Encryption string
	Timeout    time.Duration
}

// Mailer sends email through one SMTP server.
type Mailer struct {
	cfg Config
}

// ErrNotConfigured is returned when no SMTP host is set.
var ErrNotConfigured = errors.New("smtp is not configured")

// New returns a Mailer. It never fails; Send reports ErrNotConfigured when the
// host or sender address is missing.
func New(cfg Config) *Mailer {
	cfg.Encryption = strings.ToLower(strings.TrimSpace(cfg.Encryption))
	if cfg.Encryption == "" {
		if cfg.Port == 465 {
			cfg.Encryption = EncryptionSSL
		} else {
			cfg.Encryption = EncryptionStartTLS
		}
	}
	if cfg.Port == 0 {
		cfg.Port = 587
	}
	if cfg.Timeout == 0 {
		cfg.Timeout = 15 * time.Second
	}
	if cfg.FromEmail == "" {
		cfg.FromEmail = cfg.Username
	}
	return &Mailer{cfg: cfg}
}

// Configured reports whether the mailer has enough settings to send.
func (m *Mailer) Configured() bool {
	return m != nil && m.cfg.Host != "" && m.cfg.FromEmail != ""
}

// Send delivers a message with a plain-text body and an optional HTML body.
func (m *Mailer) Send(to, subject, textBody, htmlBody string) error {
	if !m.Configured() {
		return ErrNotConfigured
	}
	if _, err := mail.ParseAddress(to); err != nil {
		return fmt.Errorf("invalid recipient address: %w", err)
	}

	msg, err := m.buildMessage(to, subject, textBody, htmlBody)
	if err != nil {
		return err
	}

	addr := net.JoinHostPort(m.cfg.Host, fmt.Sprint(m.cfg.Port))
	dialer := &net.Dialer{Timeout: m.cfg.Timeout}
	tlsCfg := &tls.Config{ServerName: m.cfg.Host, MinVersion: tls.VersionTLS12}

	var conn net.Conn
	if m.cfg.Encryption == EncryptionSSL {
		conn, err = tls.DialWithDialer(dialer, "tcp", addr, tlsCfg)
	} else {
		conn, err = dialer.Dial("tcp", addr)
	}
	if err != nil {
		return fmt.Errorf("smtp connect %s: %w", addr, err)
	}
	_ = conn.SetDeadline(time.Now().Add(2 * m.cfg.Timeout))

	c, err := smtp.NewClient(conn, m.cfg.Host)
	if err != nil {
		conn.Close()
		return fmt.Errorf("smtp handshake: %w", err)
	}
	defer c.Close()

	if m.cfg.Encryption == EncryptionStartTLS {
		if ok, _ := c.Extension("STARTTLS"); !ok {
			return errors.New("smtp server does not support STARTTLS; set encryption to \"ssl\" or \"none\"")
		}
		if err := c.StartTLS(tlsCfg); err != nil {
			return fmt.Errorf("smtp starttls: %w", err)
		}
	}

	if m.cfg.Username != "" {
		if ok, _ := c.Extension("AUTH"); ok {
			if err := c.Auth(smtp.PlainAuth("", m.cfg.Username, m.cfg.Password, m.cfg.Host)); err != nil {
				return fmt.Errorf("smtp auth: %w", err)
			}
		}
	}

	if err := c.Mail(m.cfg.FromEmail); err != nil {
		return fmt.Errorf("smtp MAIL FROM: %w", err)
	}
	if err := c.Rcpt(to); err != nil {
		return fmt.Errorf("smtp RCPT TO: %w", err)
	}
	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("smtp DATA: %w", err)
	}
	if _, err := w.Write(msg); err != nil {
		return fmt.Errorf("smtp write: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp send: %w", err)
	}
	return c.Quit()
}

func (m *Mailer) buildMessage(to, subject, textBody, htmlBody string) ([]byte, error) {
	from := mail.Address{Name: m.cfg.FromName, Address: m.cfg.FromEmail}
	domain := m.cfg.FromEmail[strings.LastIndex(m.cfg.FromEmail, "@")+1:]

	var b strings.Builder
	header := func(k, v string) { b.WriteString(k + ": " + v + "\r\n") }
	header("From", from.String())
	header("To", to)
	header("Subject", mime.QEncoding.Encode("utf-8", subject))
	header("Date", time.Now().Format(time.RFC1123Z))
	header("Message-ID", fmt.Sprintf("<%d@%s>", time.Now().UnixNano(), domain))
	header("MIME-Version", "1.0")

	if htmlBody == "" {
		header("Content-Type", "text/plain; charset=utf-8")
		header("Content-Transfer-Encoding", "8bit")
		b.WriteString("\r\n" + normalizeCRLF(textBody))
		return []byte(b.String()), nil
	}

	boundary := fmt.Sprintf("songothon-%d", time.Now().UnixNano())
	header("Content-Type", `multipart/alternative; boundary="`+boundary+`"`)
	b.WriteString("\r\n")
	for _, part := range []struct{ ctype, body string }{
		{"text/plain", textBody},
		{"text/html", htmlBody},
	} {
		b.WriteString("--" + boundary + "\r\n")
		header("Content-Type", part.ctype+"; charset=utf-8")
		header("Content-Transfer-Encoding", "8bit")
		b.WriteString("\r\n" + normalizeCRLF(part.body) + "\r\n")
	}
	b.WriteString("--" + boundary + "--\r\n")
	return []byte(b.String()), nil
}

func normalizeCRLF(s string) string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	return strings.ReplaceAll(s, "\n", "\r\n")
}
