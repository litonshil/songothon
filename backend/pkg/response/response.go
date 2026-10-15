package response

import (
	"net/http"

	"github.com/labstack/echo/v4"
)

type APIResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message,omitempty"`
	Data    any    `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

func JSON(c echo.Context, statusCode int, success bool, message string, data any) error {
	return c.JSON(statusCode, APIResponse{
		Success: success,
		Message: message,
		Data:    data,
	})
}

func Success(c echo.Context, message string, data any) error {
	return JSON(c, http.StatusOK, true, message, data)
}

func Created(c echo.Context, message string, data any) error {
	return JSON(c, http.StatusCreated, true, message, data)
}

func Error(c echo.Context, statusCode int, errMessage string) error {
	return c.JSON(statusCode, APIResponse{
		Success: false,
		Error:   errMessage,
	})
}

func BadRequest(c echo.Context, errMessage string) error {
	return Error(c, http.StatusBadRequest, errMessage)
}

func Unauthorized(c echo.Context, errMessage string) error {
	if errMessage == "" {
		errMessage = "Unauthorized access"
	}
	return Error(c, http.StatusUnauthorized, errMessage)
}

func Forbidden(c echo.Context, errMessage string) error {
	if errMessage == "" {
		errMessage = "Forbidden: insufficient permissions"
	}
	return Error(c, http.StatusForbidden, errMessage)
}

func NotFound(c echo.Context, errMessage string) error {
	if errMessage == "" {
		errMessage = "Resource not found"
	}
	return Error(c, http.StatusNotFound, errMessage)
}

func InternalError(c echo.Context, errMessage string) error {
	if errMessage == "" {
		errMessage = "An internal server error occurred"
	}
	return Error(c, http.StatusInternalServerError, errMessage)
}
