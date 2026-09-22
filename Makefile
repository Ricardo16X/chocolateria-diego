# =============================================================================
# Artesanal Chocolate Diego — tareas frecuentes
# =============================================================================
.DEFAULT_GOAL := ayuda
COMPOSE := docker compose
VERSION ?= dev

.PHONY: ayuda preparar instalar-laravel activos base construir arriba abajo reiniciar \
        registros estado consola mysql redis verificar probar evidencias limpiar

ayuda: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

preparar: ## Crea el archivo .env a partir del ejemplo
	@test -f .env || cp .env.example .env
	@echo "Archivo .env listo. Cambie DB_PASSWORD y DB_ROOT_PASSWORD."

instalar-laravel: ## Crea el proyecto Laravel 10 dentro de src/
	@if [ -f src/artisan ]; then echo "Ya existe una aplicacion en src/."; exit 0; fi
	docker run --rm -v "$(CURDIR)/src:/app:Z" -w /app composer:2.7 \
		create-project laravel/laravel:^10.0 . --prefer-dist --no-interaction
	@echo "Laravel instalado. Siguiente paso: make construir"

activos: ## Compila CSS/JS (Tailwind/Vite) sin instalar Node en el equipo
	docker run --rm -v "$(CURDIR)/src:/app:Z" -w /app node:20-alpine \
		sh -c "npm install && npm run build"
	@echo "Activos compilados en src/public/build/. Necesario tras clonar el"
	@echo "repositorio o modificar una vista Blade o un archivo CSS/JS."

base: ## Construye solo la imagen base comun
	docker build -f docker/base/Dockerfile -t chocolate-diego/base:$(VERSION) .

construir: base ## Construye la imagen base y los cuatro microservicios
	APP_VERSION=$(VERSION) $(COMPOSE) build

arriba: ## Levanta todos los servicios
	$(COMPOSE) up -d
	@echo ""
	@echo "  Puerta de enlace:  http://localhost:8080"
	@echo "  Bandeja de correo: http://localhost:8025"
	@echo "  MySQL:             localhost:3307"

abajo: ## Detiene los servicios conservando los datos
	$(COMPOSE) down

reiniciar: abajo arriba ## Reinicia los servicios

registros: ## Sigue los registros de todos los servicios
	$(COMPOSE) logs -f --tail=100

estado: ## Estado de los contenedores
	$(COMPOSE) ps

consola: ## Terminal dentro del microservicio catalogo
	$(COMPOSE) exec catalogo bash

mysql: ## Cliente de MySQL
	$(COMPOSE) exec db sh -c 'mysql -u root -p"$$MYSQL_ROOT_PASSWORD" "$$MYSQL_DATABASE"'

redis: ## Cliente de Redis
	$(COMPOSE) exec cache redis-cli

verificar: ## Verifica el esquema contra el documento
	$(COMPOSE) exec -T db bash -c 'DB_HOST=localhost DB_USER=root \
		DB_PASS="$$MYSQL_ROOT_PASSWORD" DB_NAME="$$MYSQL_DATABASE" bash -s' \
		< scripts/verificar-esquema.sh

probar: ## Ejecuta las pruebas de humo
	bash tests/humo/pruebas-humo.sh

evidencias: ## Genera las evidencias tecnicas de DEVOPS 1
	bash scripts/evidencias.sh

limpiar: ## Elimina contenedores, volumenes y datos. Destructivo.
	$(COMPOSE) down -v --remove-orphans
	@echo "Volumenes eliminados. La base se recrea al levantar."
