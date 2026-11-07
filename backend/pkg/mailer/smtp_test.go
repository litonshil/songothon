package mailer

import (
	"bufio"
	"net"
	"strings"
	"testing"
	"time"
)

// fakeSMTP accepts one plain-text SMTP session and returns the DATA payload.
func fakeSMTP(t *testing.T) (port int, got <-chan string) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ch := make(chan string, 1)
	go func() {
		defer ln.Close()
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		r := bufio.NewReader(conn)
		write := func(s string) { conn.Write([]byte(s + "\r\n")) }
		write("220 fake ESMTP")
		var data strings.Builder
		inData := false
		for {
			line, err := r.ReadString('\n')
			if err != nil {
				return
			}
			if inData {
				if line == ".\r\n" {
					inData = false
					write("250 queued")
					continue
				}
				data.WriteString(line)
				continue
			}
			cmd := strings.ToUpper(strings.TrimSpace(line))
			switch {
			case strings.HasPrefix(cmd, "EHLO"), strings.HasPrefix(cmd, "HELO"):
				write("250 fake")
			case cmd == "DATA":
				inData = true
				write("354 go ahead")
			case cmd == "QUIT":
				write("221 bye")
				ch <- data.String()
				return
			default:
				write("250 ok")
			}
		}
	}()
	return ln.Addr().(*net.TCPAddr).Port, ch
}

func TestSendPlainSMTP(t *testing.T) {
	port, got := fakeSMTP(t)
	m := New(Config{Host: "127.0.0.1", Port: port, FromEmail: "no-reply@example.com", FromName: "Songothon", Encryption: EncryptionNone})
	if err := m.Send("user@example.com", "Reset code", "Code: ABCD-EFGH", "<b>ABCD-EFGH</b>"); err != nil {
		t.Fatalf("send: %v", err)
	}
	select {
	case msg := <-got:
		for _, want := range []string{"To: user@example.com", "Subject: Reset code", "multipart/alternative", "Code: ABCD-EFGH", "<b>ABCD-EFGH</b>"} {
			if !strings.Contains(msg, want) {
				t.Errorf("message missing %q:\n%s", want, msg)
			}
		}
	case <-time.After(3 * time.Second):
		t.Fatal("no message received")
	}
}

func TestNotConfigured(t *testing.T) {
	if err := New(Config{}).Send("a@b.com", "s", "b", ""); err != ErrNotConfigured {
		t.Fatalf("want ErrNotConfigured, got %v", err)
	}
}
