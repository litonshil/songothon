package service

import (
	"strings"
	"testing"
)

func TestResetCodeNormalization(t *testing.T) {
	code, err := generateResetCode()
	if err != nil || len(code) != resetCodeLength {
		t.Fatalf("bad code %q: %v", code, err)
	}
	display := strings.ToLower(code[:4] + "-" + code[4:])
	if hashResetCode(display) != hashResetCode(code) || hashResetCode(" "+display+" ") != hashResetCode(code) {
		t.Fatal("formatted code should hash the same as the raw code")
	}
}
