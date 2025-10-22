.PHONY: help setup install start stop clean run incidents export test status

help:
	@echo "DORA Metrics System - Available Commands"
	@echo "========================================"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make setup        - Run initial setup (interactive)"
	@echo "  make install      - Install Python dependencies"
	@echo "  make start        - Start PostgreSQL database"
	@echo "  make stop         - Stop PostgreSQL database"
	@echo ""
	@echo "Data Management:"
	@echo "  make incidents    - Create test incidents on GitHub"
	@echo "  make run          - Run complete DORA pipeline"
	@echo "  make export       - Export metrics to CSV only"
	@echo ""
	@echo "Maintenance:"
	@echo "  make status       - Check system status"
	@echo "  make clean        - Clean exports and reset database"
	@echo "  make test         - Test database connection"
	@echo ""

setup:
	@echo "Running setup script..."
	@./setup.sh

install:
	@echo "Installing Python dependencies..."
	@cd dora && python3 -m venv venv && . venv/bin/activate && pip install -q -r requirements.txt
	@echo "✓ Dependencies installed"

start:
	@echo "Starting PostgreSQL..."
	@docker-compose up -d
	@echo "✓ PostgreSQL started"
	@sleep 3
	@docker-compose ps

stop:
	@echo "Stopping PostgreSQL..."
	@docker-compose down
	@echo "✓ PostgreSQL stopped"

incidents:
	@echo "Creating test incidents..."
	@cd dora && . venv/bin/activate && python create_test_incidents.py

run:
	@echo "Running DORA pipeline..."
	@cd dora && . venv/bin/activate && python run_dora_pipeline.py
	@echo ""
	@echo "Results are in dora/exports/"

export:
	@echo "Exporting metrics..."
	@cd dora && . venv/bin/activate && python export_metrics.py

status:
	@echo "System Status"
	@echo "============="
	@echo ""
	@echo "PostgreSQL:"
	@docker-compose ps
	@echo ""
	@echo "Python environment:"
	@if [ -d "dora/venv" ]; then echo "✓ Virtual environment exists"; else echo "✗ Virtual environment missing (run: make install)"; fi
	@echo ""
	@echo "Configuration:"
	@if [ -f ".env" ]; then echo "✓ .env file exists"; else echo "✗ .env file missing (run: make setup)"; fi

test:
	@echo "Testing database connection..."
	@docker exec dora-postgres psql -U dora_user -d dora_metrics -c "SELECT COUNT(*) FROM deployments;" || echo "Error connecting to database"

clean:
	@echo "Cleaning exports and resetting database..."
	@rm -rf dora/exports/*.csv
	@docker-compose down -v
	@echo "✓ Cleaned"

.DEFAULT_GOAL := help
