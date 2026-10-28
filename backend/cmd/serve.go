package cmd

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
	"github.com/spf13/cobra"

	"songothon/client/conn"
	"songothon/config"
	"songothon/internal/handler"
	appmw "songothon/internal/middleware"
	"songothon/internal/repository/postgres"
	"songothon/internal/service"
	"songothon/internal/worker"
	"songothon/pkg/fcm"
	"songothon/pkg/response"
	"songothon/pkg/token"
)

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the Songothon HTTP server",
	Run: func(cmd *cobra.Command, args []string) {
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()

		if err := runServer(ctx); err != nil {
			log.Fatalf("Server stopped unexpectedly: %v", err)
		}
	},
}

func runServer(ctx context.Context) error {
	appCfg := config.App()
	fcmCfg := config.FCM().FCM

	log.Println("Starting Songothon Multi-Tenant Platform API Server...")

	// 1. Repositories
	db := postgres.NewDB(conn.Db())
	userRepo := postgres.NewUserRepository(db)
	orgRepo := postgres.NewOrgRepository(db)
	contribRepo := postgres.NewContributionRepository(db)
	invRepo := postgres.NewInvestmentRepository(db)
	expRepo := postgres.NewExpenseRepository(db)
	incRepo := postgres.NewIncomeRepository(db)
	notifRepo := postgres.NewNotificationRepository(db)
	auditRepo := postgres.NewAuditRepository(db)

	// 2. Shared modules
	tokenMgr := token.NewTokenManager(appCfg.JWTSecret, time.Duration(appCfg.JWTExpiryHours)*time.Hour, "songothon-api")
	fcmClient := fcm.NewFCMClient(fcmCfg.ServerKey, fcmCfg.ProjectID)

	// 3. Services
	notifService := service.NewNotificationService(notifRepo, userRepo, orgRepo, fcmClient)
	authService := service.NewAuthService(userRepo, orgRepo, tokenMgr)
	orgService := service.NewOrgService(orgRepo, userRepo, auditRepo, notifService)
	contribService := service.NewContributionService(contribRepo, orgRepo, auditRepo, notifService)
	invService := service.NewInvestmentService(invRepo, auditRepo)
	expService := service.NewExpenseService(expRepo, auditRepo)
	incService := service.NewIncomeService(incRepo, auditRepo)
	reportService := service.NewReportService(orgRepo, contribRepo, invRepo, expRepo, incRepo)

	// 4. Handlers
	authHandler := handler.NewAuthHandler(authService)
	orgHandler := handler.NewOrgHandler(orgService)
	contribHandler := handler.NewContributionHandler(contribService)
	invHandler := handler.NewInvestmentHandler(invService)
	expHandler := handler.NewExpenseHandler(expService)
	incHandler := handler.NewIncomeHandler(incService)
	reportHandler := handler.NewReportHandler(reportService)
	notifHandler := handler.NewNotificationHandler(notifService)

	// 5. Background dues worker
	workerCtx, workerCancel := context.WithCancel(context.Background())
	defer workerCancel()

	duesWorker := worker.NewDuesWorker(db.Pool, notifService, 6*time.Hour)
	duesWorker.Start(workerCtx)

	// 6. HTTP engine
	e := echo.New()
	e.HideBanner = true

	e.Use(echomw.LoggerWithConfig(echomw.LoggerConfig{
		Format: "[${time_rfc3339}] ${status} ${method} ${uri} (${latency_human})\n",
	}))
	e.Use(echomw.Recover())
	e.Use(echomw.CORSWithConfig(echomw.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization, "X-Org-Slug", "X-Org-ID"},
	}))

	e.GET("/health", func(c echo.Context) error {
		return response.Success(c, "Songothon API is online and healthy", echo.Map{
			"timestamp": time.Now().UTC().Format(time.RFC3339),
			"env":       appCfg.Env,
		})
	})

	v1 := e.Group("/api/v1")

	// --- Public Auth Routes ---
	v1.POST("/auth/register", authHandler.Register)
	v1.POST("/auth/login", authHandler.Login)
	v1.POST("/auth/forgot-password", authHandler.ForgotPassword)
	v1.POST("/auth/reset-password", authHandler.ResetPassword)
	// Logout is public so an expired token doesn't block the client from
	// clearing its FCM registration. Token is parsed internally if present.
	v1.POST("/auth/logout", authHandler.LogoutPublic(tokenMgr))

	// --- Authenticated Base Routes (User-Scoped) ---
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

	// --- Multi-Tenant Routes (Tenant-Scoped) ---
	// Resolves tenant via URL slug param ':slug' or 'X-Org-Slug' header
	tenantGroup := authGroup.Group("/organizations/:slug")
	tenantGroup.Use(appmw.TenantMiddleware(orgRepo))

	// Tenant Member Endpoints (Accessible to all active members of the tenant)
	tenantGroup.GET("", orgHandler.GetOrg)
	tenantGroup.GET("/dashboard/member", reportHandler.GetMemberDashboard)
	tenantGroup.GET("/collections", reportHandler.ListCollections)
	tenantGroup.GET("/collections/:cycle", reportHandler.GetCollectionCycle)
	tenantGroup.GET("/members", orgHandler.ListMembers)
	tenantGroup.POST("/contributions/submit", contribHandler.SubmitDeposit)
	tenantGroup.GET("/contributions/my-history", contribHandler.ListMyHistory)
	tenantGroup.GET("/investments", invHandler.ListInvestments)
	tenantGroup.GET("/investments/:id", invHandler.GetByID)
	tenantGroup.GET("/investments/metrics", invHandler.GetPortfolioMetrics)
	tenantGroup.GET("/down-payments", orgHandler.ListDownPaymentSchemes)
	tenantGroup.GET("/expenses", expHandler.ListExpenses)
	tenantGroup.GET("/incomes", incHandler.ListIncomes)

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
	adminGroup.POST("/expenses", expHandler.CreateExpense)
	adminGroup.POST("/incomes", incHandler.CreateIncome)
	adminGroup.POST("/notifications/broadcast", notifHandler.Broadcast)
	adminGroup.POST("/notifications/schedule", notifHandler.Schedule)
	adminGroup.GET("/notifications/scheduled", notifHandler.ListScheduled)
	adminGroup.DELETE("/notifications/scheduled/:id", notifHandler.DeleteScheduled)

	// 7. Start server and shut down gracefully when ctx is cancelled
	serverErr := make(chan error, 1)
	go func() {
		addr := fmt.Sprintf(":%d", appCfg.Port)
		log.Printf("Server listening on port %d (env: %s)\n", appCfg.Port, appCfg.Env)
		if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
			serverErr <- err
		}
		close(serverErr)
	}()

	select {
	case err := <-serverErr:
		return err
	case <-ctx.Done():
	}

	log.Println("Shutting down API server gracefully...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := e.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("server forced to shutdown: %w", err)
	}

	log.Println("Server exiting complete.")
	return nil
}

func RegisterServeCommand() {
	RegisterSubCommand(serveCmd)
}
