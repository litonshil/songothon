package handler

import (
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"

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
		return response.BadRequest(c, "Invalid request payload")
	}

	res, err := h.authService.Register(c.Request().Context(), &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}

	return response.Created(c, "Account registered successfully", res)
}

func (h *AuthHandler) Login(c echo.Context) error {
	var req domain.LoginRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid request payload")
	}

	res, err := h.authService.Login(c.Request().Context(), &req)
	if err != nil {
		return response.Unauthorized(c, err.Error())
	}

	return response.Success(c, "Login successful", res)
}

func (h *AuthHandler) Me(c echo.Context) error {
	userID, err := middleware.GetCurrentUserID(c)
	if err != nil {
		return response.Unauthorized(c, "User session not found")
	}

	profile, err := h.authService.GetProfile(c.Request().Context(), userID)
	if err != nil {
		return response.NotFound(c, err.Error())
	}

	return response.Success(c, "Profile retrieved successfully", profile)
}
