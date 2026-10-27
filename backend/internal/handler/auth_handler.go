package handler

import (
	"log"
	"strings"

	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
	"songothon/pkg/token"

	"github.com/labstack/echo/v4"
)

type AuthHandler struct {
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

func (h *AuthHandler) Register(c echo.Context) error {
	var req domain.RegisterRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request body payload")
	}

	res, err := h.authService.Register(c.Request().Context(), &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Registration successful", res)
}

func (h *AuthHandler) Login(c echo.Context) error {
	var req domain.LoginRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid login credentials payload")
	}

	res, err := h.authService.Login(c.Request().Context(), &req)
	if err != nil {
		log.Printf("[AuthHandler] Login failed for %s: %v\n", req.Email, err)
		return response.Unauthorized(c, err.Error())
	}

	return response.Success(c, "Login successful", res)
}

func (h *AuthHandler) Me(c echo.Context) error {
	userID := middleware.GetUserID(c)
	user, err := h.authService.Me(c.Request().Context(), userID)
	if err != nil {
		return response.NotFound(c, err.Error())
	}

	return response.Success(c, "Current user profile", user)
}

func (h *AuthHandler) UpdateFCMToken(c echo.Context) error {
	userID := middleware.GetUserID(c)
	var req domain.UpdateFCMTokenRequest
	if err := c.Bind(&req); err != nil || req.FCMToken == "" {
		return response.BadRequest(c, "fcm_token is required")
	}

	if err := h.authService.UpdateFCMToken(c.Request().Context(), userID, req.FCMToken); err != nil {
		return response.InternalError(c, "Failed to update FCM device token")
	}

	return response.Success(c, "FCM token registered successfully", nil)
}

func (h *AuthHandler) Logout(c echo.Context) error {
	userID := middleware.GetUserID(c)
	if err := h.authService.Logout(c.Request().Context(), userID); err != nil {
		// Non-fatal: log but still allow client to complete logout
		log.Printf("[AuthHandler] Logout FCM clear failed for user %s: %v\n", userID, err)
	}
	return response.Success(c, "Logged out successfully", nil)
}

// LogoutPublic handles logout when the JWT may be expired or absent.
// It attempts to parse the Bearer token itself; if valid, clears the FCM token.
// Always returns 200 so the client can complete its local session teardown.
func (h *AuthHandler) LogoutPublic(tm *token.TokenManager) echo.HandlerFunc {
	return func(c echo.Context) error {
		authHeader := c.Request().Header.Get("Authorization")
		if authHeader != "" {
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
				if claims, err := tm.ValidateToken(parts[1]); err == nil {
					if clearErr := h.authService.Logout(c.Request().Context(), claims.UserID); clearErr != nil {
						log.Printf("[AuthHandler] LogoutPublic FCM clear failed for user %s: %v\n", claims.UserID, clearErr)
					}
				}
			}
		}
		return response.Success(c, "Logged out successfully", nil)
	}
}

func (h *AuthHandler) ForgotPassword(c echo.Context) error {
	var req domain.ForgotPasswordRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid forgot-password payload")
	}
	res, err := h.authService.ForgotPassword(c.Request().Context(), req.Email)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, res.Message, res)
}

func (h *AuthHandler) ResetPassword(c echo.Context) error {
	var req domain.ResetPasswordRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid reset-password payload")
	}
	if err := h.authService.ResetPassword(c.Request().Context(), &req); err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Password reset successfully. Please sign in with your new password.", nil)
}
