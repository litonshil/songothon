package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/labstack/echo/v4"
	echomw "github.com/labstack/echo/v4/middleware"

	"songothon/internal/config"
	"songothon/internal/handler"
	appmw "songothon/internal/middleware"
	"songothon/internal/repository/postgres"
	"songothon/internal/service"
	"songothon/internal/worker"
	"songothon/pkg/fcm"
	"songothon/pkg/response"
	"songothon/pkg/token"
)

func main() {
	log.Println("Starting Songothon Multi-Tenant Platform API Server...")

	// 1. Load Configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load environment configuration: %v", err)
	}

	// 2. Initialize Database Pool & Run Migrations
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()

	db, err := postgres.NewDB(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer db.Close()

	// 3. Initialize Shared Modules (Token Manager, FCM Client)
	tokenMgr := token.NewTokenManager(cfg.JWTSecret, cfg.JWTExpiry, "songothon-api")
	fcmClient := fcm.NewFCMClient(cfg.FCMServerKey, cfg.FCMProjectID)

	// 4. Initialize Repositories
	userRepo := postgres.NewUserRepository(db)
	orgRepo := postgres.NewOrgRepository(db)
	contribRepo := postgres.NewContributionRepository(db)
	invRepo := postgres.NewInvestmentRepository(db)
	notifRepo := postgres.NewNotificationRepository(db)
	auditRepo := postgres.NewAuditRepository(db)

	// 5. Initialize Services
	notifService := service.NewNotificationService(notifRepo, userRepo, orgRepo, fcmClient)
	authService := service.NewAuthService(userRepo, orgRepo, tokenMgr)
	orgService := service.NewOrgService(orgRepo, userRepo, auditRepo, notifService)
	contribService := service.NewContributionService(contribRepo, orgRepo, auditRepo, notifService)
	invService := service.NewInvestmentService(invRepo, auditRepo)
	reportService := service.NewReportService(orgRepo, contribRepo, invRepo)

	// 6. Initialize Handlers
	authHandler := handler.NewAuthHandler(authService)
	orgHandler := handler.NewOrgHandler(orgService)
	contribHandler := handler.NewContributionHandler(contribService)
	invHandler := handler.NewInvestmentHandler(invService)
	reportHandler := handler.NewReportHandler(reportService)
	notifHandler := handler.NewNotificationHandler(notifService)

	// 7. Initialize & Start Background Dues Worker
	workerCtx, workerCancel := context.WithCancel(context.Background())
	defer workerCancel()

	duesWorker := worker.NewDuesWorker(db.Pool, notifService, 6*time.Hour)
	duesWorker.Start(workerCtx)

	// 8. Setup Echo HTTP Engine
	e := echo.New()
	e.HideBanner = true

	// Standard Global Middlewares
	e.Use(echomw.LoggerWithConfig(echomw.LoggerConfig{
		Format: "[${time_rfc3339}] ${status} ${method} ${uri} (${latency_human})\n",
	}))
	e.Use(echomw.Recover())
	e.Use(echomw.CORSWithConfig(echomw.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization, "X-Org-Slug", "X-Org-ID"},
	}))

	// Health Check
	e.GET("/health", func(c echo.Context) error {
		return response.Success(c, "Songothon API is online and healthy", echo.Map{
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"env":       cfg.AppEnv,
		})
	})

	// API v1 Routing
	v1 := e.Group("/api/v1")

	// --- 8.1 Public Auth Routes ---
	v1.POST("/auth/register", authHandler.Register)
	v1.POST("/auth/login", authHandler.Login)
	v1.POST("/auth/forgot-password", authHandler.ForgotPassword)
	v1.POST("/auth/reset-password", authHandler.ResetPassword)
	// Logout is public so an expired token doesn't block the client from
	// clearing its FCM registration. Token is parsed internally if present.
	v1.POST("/auth/logout", authHandler.LogoutPublic(tokenMgr))

	// --- 8.2 Authenticated Base Routes (User-Scoped) ---
	authGroup := v1.Group("")
	authGroup.Use(appmw.AuthMiddleware(tokenMgr))

	authGroup.GET("/auth/me", authHandler.Me)
	authGroup.POST("/auth/fcm-token", authHandler.UpdateFCMToken)
	authGroup.GET("/notifications", notifHandler.ListMyNotifications)
	authGroup.PATCH("/notifications/:id/read", notifHandler.MarkAsRead)
	authGroup.POST("/notifications/read-all", notifHandler.MarkAllAsRead)

	// Organization Membership Base Operations
	authGroup.POST("/organizations", orgHandler.CreateOrg)
	authGroup.GET("/organizations", orgHandler.ListMyOrgs)
	authGroup.POST("/organizations/join", orgHandler.JoinOrg)

	// --- 8.3 Multi-Tenant Routes (Tenant-Scoped) ---
	// Resolves tenant via URL slug param ':slug' or 'X-Org-Slug' header
	tenantGroup := authGroup.Group("/organizations/:slug")
	tenantGroup.Use(appmw.TenantMiddleware(orgRepo))

	// Tenant Member Endpoints (Accessible to all active members of the tenant)
	tenantGroup.GET("", orgHandler.GetOrg)
	tenantGroup.GET("/dashboard/member", reportHandler.GetMemberDashboard)
	tenantGroup.GET("/members", orgHandler.ListMembers)
	tenantGroup.POST("/contributions/submit", contribHandler.SubmitDeposit)
	tenantGroup.GET("/contributions/my-history", contribHandler.ListMyHistory)
	tenantGroup.GET("/investments", invHandler.ListInvestments)
	tenantGroup.GET("/investments/:id", invHandler.GetByID)
	tenantGroup.GET("/investments/metrics", invHandler.GetPortfolioMetrics)
	tenantGroup.GET("/down-payments", orgHandler.ListDownPaymentSchemes)

	// Tenant Org-Admin Endpoints (Restricted to 'org_admin' role in this tenant)
	adminGroup := tenantGroup.Group("/admin")
	adminGroup.Use(appmw.RequireOrgAdmin())

	adminGroup.GET("/dashboard", reportHandler.GetAdminDashboard)
	adminGroup.GET("/contributions/pending", contribHandler.ListPending)
	adminGroup.GET("/contributions", contribHandler.ListAll)
	adminGroup.POST("/contributions/:id/approve", contribHandler.ApproveDeposit)
	adminGroup.POST("/contributions/:id/reject", contribHandler.RejectDeposit)
	adminGroup.POST("/members/invite", orgHandler.InviteMember)
	adminGroup.PATCH("/members/:member_id", orgHandler.UpdateMember)
	adminGroup.DELETE("/members/:member_id", orgHandler.RemoveMember)
	adminGroup.GET("/join-requests", orgHandler.ListJoinRequests)
	adminGroup.POST("/join-requests/:member_id/approve", orgHandler.ApproveJoinRequest)
	adminGroup.POST("/join-requests/:member_id/reject", orgHandler.RejectJoinRequest)
	adminGroup.GET("/invitations", orgHandler.ListInvitations)
	adminGroup.PATCH("/privacy", orgHandler.UpdatePrivacy)
	adminGroup.POST("/share-config", orgHandler.ConfigureShares)
	adminGroup.POST("/down-payments", orgHandler.CreateDownPaymentScheme)
	adminGroup.POST("/investments", invHandler.CreateInvestment)
	adminGroup.PUT("/investments/:id", invHandler.UpdateInvestment)
	adminGroup.DELETE("/investments/:id", invHandler.DeleteInvestment)
	adminGroup.POST("/notifications/broadcast", notifHandler.Broadcast)
	adminGroup.POST("/notifications/schedule", notifHandler.Schedule)
	adminGroup.GET("/notifications/scheduled", notifHandler.ListScheduled)
	adminGroup.DELETE("/notifications/scheduled/:id", notifHandler.DeleteScheduled)

	// 9. Start Server with Graceful Shutdown
	go func() {
		addr := fmt.Sprintf(":%s", cfg.Port)
		log.Printf("Server listening on port %s (env: %s)\n", cfg.Port, cfg.AppEnv)
		if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server stopped unexpectedly: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down API server gracefully...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := e.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exiting complete.")
}
