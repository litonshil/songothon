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
	"songothon/internal/domain"
	"songothon/internal/handler"
	appmw "songothon/internal/middleware"
	"songothon/internal/repository/postgres"
	"songothon/internal/service"
	"songothon/pkg/response"
	"songothon/pkg/token"
)

func main() {
	log.Println("Starting Songothon Community Savings API Server...")

	// 1. Load Configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load environment configuration: %v", err)
	}

	// 2. Initialize Database Pool
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	db, err := postgres.NewDB(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}
	defer db.Close()

	// 3. Initialize Token Manager
	tokenMgr := token.NewTokenManager(cfg.JWTSecret, cfg.JWTExpiry, "songothon-api")

	// 4. Initialize Repositories
	userRepo := postgres.NewUserRepository(db)
	contribRepo := postgres.NewContributionRepository(db)
	invRepo := postgres.NewInvestmentRepository(db)
	reportRepo := postgres.NewReportRepository(db)

	// 5. Initialize Services
	authService := service.NewAuthService(userRepo, tokenMgr)
	memberService := service.NewMemberService(userRepo)
	contribService := service.NewContributionService(contribRepo, userRepo)
	invService := service.NewInvestmentService(invRepo)
	reportService := service.NewReportService(reportRepo)

	// 6. Initialize Handlers
	authHandler := handler.NewAuthHandler(authService)
	memberHandler := handler.NewMemberHandler(memberService)
	contribHandler := handler.NewContributionHandler(contribService)
	invHandler := handler.NewInvestmentHandler(invService)
	reportHandler := handler.NewReportHandler(reportService)

	// 7. Setup Echo Framework
	e := echo.New()
	e.HideBanner = true

	// Standard Middlewares
	e.Use(echomw.LoggerWithConfig(echomw.LoggerConfig{
		Format: "[${time_rfc3339}] ${status} ${method} ${uri} (${latency_human})\n",
	}))
	e.Use(echomw.Recover())
	e.Use(echomw.CORSWithConfig(echomw.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization},
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

	// --- Public Auth Endpoints ---
	authGroup := v1.Group("/auth")
	authGroup.POST("/register", authHandler.Register)
	authGroup.POST("/login", authHandler.Login)

	// --- Authenticated Base Endpoints (Members + Admins) ---
	authRequired := v1.Group("")
	authRequired.Use(appmw.AuthMiddleware(tokenMgr))

	authRequired.GET("/auth/me", authHandler.Me)
	authRequired.GET("/reports/overview", reportHandler.GetOverview)

	// Member Contribution Operations & Views
	authRequired.POST("/contributions/submit", contribHandler.SubmitDeposit)
	authRequired.GET("/contributions/periods", contribHandler.ListPeriods)
	authRequired.GET("/contributions/my-history", contribHandler.GetMyHistory)
	authRequired.GET("/contributions/my-dues", contribHandler.GetMyDues)
	authRequired.GET("/contributions/monthly", contribHandler.GetMonthlyReport)
	authRequired.GET("/contributions/monthly-all", contribHandler.ListAllMonthlyReports)

	// Read-Only Investment Views
	authRequired.GET("/investments", invHandler.ListInvestments)
	authRequired.GET("/investments/:id", invHandler.GetByID)

	// --- Admin-Only Endpoints (RBAC Enforced) ---
	adminRequired := authRequired.Group("/admin")
	adminRequired.Use(appmw.RequireRole(domain.RoleAdmin))

	// Member Management
	adminRequired.GET("/members", memberHandler.ListMembers)
	adminRequired.PATCH("/members/:id/status", memberHandler.UpdateStatus)
	adminRequired.GET("/members/:id/dues", contribHandler.GetMemberFinancialSummary)

	// Contribution & Deposit Operations
	adminRequired.POST("/contributions/periods", contribHandler.CreatePeriod)
	adminRequired.POST("/contributions/deposit", contribHandler.RecordDeposit)
	adminRequired.GET("/contributions", contribHandler.ListAllContributions)
	adminRequired.GET("/contributions/pending", contribHandler.ListPendingApprovals)
	adminRequired.POST("/contributions/:id/approve", contribHandler.ApproveDeposit)
	adminRequired.POST("/contributions/:id/reject", contribHandler.RejectDeposit)

	// Investment Portfolio Controls
	adminRequired.POST("/investments", invHandler.CreateInvestment)
	adminRequired.PUT("/investments/:id", invHandler.UpdateInvestment)

	// Financial Summary & Ledger Audit
	adminRequired.GET("/reports/financial-summary", reportHandler.GetFinancialSummary)

	// 8. Graceful Shutdown
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
