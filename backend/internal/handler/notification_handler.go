package handler

import (
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"songothon/internal/domain"
	"songothon/internal/middleware"
	"songothon/internal/service"
	"songothon/pkg/response"
)

type NotificationHandler struct {
	notifService *service.NotificationService
}

func NewNotificationHandler(notifService *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{notifService: notifService}
}

func (h *NotificationHandler) ListMyNotifications(c echo.Context) error {
	userID := middleware.GetUserID(c)
	list, err := h.notifService.ListUserNotifications(c.Request().Context(), userID, 50)
	if err != nil {
		return response.InternalError(c, err.Error())
	}
	return response.Success(c, "Notifications retrieved", list)
}

func (h *NotificationHandler) MarkAsRead(c echo.Context) error {
	userID := middleware.GetUserID(c)
	idStr := c.Param("id")
	notifID, err := uuid.Parse(idStr)
	if err != nil {
		return response.BadRequest(c, "Invalid notification ID")
	}

	if err := h.notifService.MarkAsRead(c.Request().Context(), notifID, userID); err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Notification marked as read", nil)
}

func (h *NotificationHandler) Broadcast(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	var req domain.BroadcastNotificationRequest
	if err := c.Bind(&req); err != nil || req.Title == "" || req.Body == "" {
		return response.BadRequest(c, "Title and body are required for broadcast")
	}

	if err := h.notifService.SendToMembers(c.Request().Context(), org.ID, req.TargetUserIDs, req.Title, req.Body); err != nil {
		return response.InternalError(c, err.Error())
	}

	return response.Success(c, "Broadcast notification sent successfully", nil)
}

func (h *NotificationHandler) MarkAllAsRead(c echo.Context) error {
	userID := middleware.GetUserID(c)
	if err := h.notifService.MarkAllAsRead(c.Request().Context(), userID); err != nil {
		return response.InternalError(c, err.Error())
	}
	return response.Success(c, "All notifications marked as read", nil)
}

func (h *NotificationHandler) Schedule(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	adminID := middleware.GetUserID(c)
	var req domain.ScheduleNotificationRequest
	if err := c.Bind(&req); err != nil {
		return response.BadRequest(c, "Invalid scheduled notification payload")
	}
	scheduled, err := h.notifService.Schedule(c.Request().Context(), org.ID, adminID, &req)
	if err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Created(c, "Notification scheduled successfully", scheduled)
}

func (h *NotificationHandler) ListScheduled(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	list, err := h.notifService.ListScheduled(c.Request().Context(), org.ID)
	if err != nil {
		return response.InternalError(c, err.Error())
	}
	return response.Success(c, "Scheduled notifications retrieved", list)
}

func (h *NotificationHandler) DeleteScheduled(c echo.Context) error {
	org := middleware.GetCurrentOrg(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return response.BadRequest(c, "Invalid scheduled notification ID")
	}
	if err := h.notifService.DeleteScheduled(c.Request().Context(), org.ID, id); err != nil {
		return response.BadRequest(c, err.Error())
	}
	return response.Success(c, "Scheduled notification cancelled", nil)
}
