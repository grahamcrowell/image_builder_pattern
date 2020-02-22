APP_NAME=mock_python_app
BASE_DOCKER_TAG=base
BASE_DOCKER_CONTAINER=${APP_NAME}-${BASE_DOCKER_TAG}
BASE_DOCKER_IMAGE=${APP_NAME}:${BASE_DOCKER_TAG}
DEV_DOCKER_TAG=dev
DEV_DOCKER_IMAGE=${APP_NAME}:${DEV_DOCKER_TAG}
PROD_DOCKER_TAG=prod
PROD_DOCKER_IMAGE=${APP_NAME}:${PROD_DOCKER_TAG}
DOCKER_REPO=rubikloud

.PHONY: help

help:
	@echo "-------------------"
	@echo "config:"
	@echo "-------------------"
	@echo "APP_NAME=${APP_NAME}"
	@echo "BASE_DOCKER_TAG=${BASE_DOCKER_TAG}"
	@echo "BASE_DOCKER_CONTAINER=${BASE_DOCKER_CONTAINER}"
	@echo "BASE_DOCKER_IMAGE=${BASE_DOCKER_IMAGE}"
	@echo "DEV_DOCKER_TAG=${DEV_DOCKER_TAG}"
	@echo "DEV_DOCKER_IMAGE=${DEV_DOCKER_IMAGE}"
	@echo "PROD_DOCKER_TAG=${PROD_DOCKER_TAG}"
	@echo "PROD_DOCKER_IMAGE=${PROD_DOCKER_IMAGE}"
	@echo "DOCKER_REPO=${DOCKER_REPO}"
	@echo "-------------------"
	@echo ""

base:
	@echo "-------------------"
	@echo "build base image (with cache): ${BASE_DOCKER_IMAGE}"
	@echo "-------------------"
	docker build --file Dockerfile.base --tag ${BASE_DOCKER_IMAGE} .

lock: base
	@echo "-------------------"
	@echo "pipenv lock: ${BASE_DOCKER_IMAGE}"
	@echo "-------------------"
	docker container ls --all --filter name=${BASE_DOCKER_CONTAINER} --format '{{ .Names}}' | xargs -I'{}' docker rm '{}'
	docker run --name ${BASE_DOCKER_CONTAINER} ${BASE_DOCKER_IMAGE} pipenv lock
	docker cp ${BASE_DOCKER_CONTAINER}:/app/Pipfile.lock .

dev: base
	@echo "-------------------"
	@echo "build dev image (with cache) on top of base image: ${DEV_DOCKER_IMAGE}"
	@echo "-------------------"
	docker build --file Dockerfile.dev --tag ${DEV_DOCKER_IMAGE} .

rebuild-base: clean
	@echo "-------------------"
	@echo "pipenv update and rebuild base image (without cache): ${BASE_DOCKER_IMAGE}"
	@echo "-------------------"
	docker build --no-cache --file Dockerfile.base --tag ${BASE_DOCKER_IMAGE} .

rebuild-dev: base clean
	@echo "-------------------"
	@echo "rebuild dev image (without cache): ${DEV_DOCKER_IMAGE}"
	@echo "-------------------"
	docker build --no-cache --file Dockerfile.dev --tag ${DEV_DOCKER_IMAGE} .

rebuild-all:
	@echo "-------------------"
	@echo "complete rebuild (without cache): ${BASE_DOCKER_IMAGE} and ${DEV_DOCKER_IMAGE}"
	@echo "-------------------"
	make rebuild-base
	make rebuild-dev

version: dev
	@echo "-------------------"
	@echo "show ${APP_NAME} version in ${DEV_DOCKER_IMAGE}"
	@echo "-------------------"
	docker run ${DEV_DOCKER_IMAGE} python setup.py --version

test: dev
	@echo "-------------------"
	@echo "pytest via docker-compose.test.yml"
	@echo "-------------------"
	docker-compose --file docker-compose.yml --file docker-compose.test.yml down --volumes --remove-orphans
	docker-compose --file docker-compose.yml --file docker-compose.test.yml up --exit-code-from orchestrator-tester


lint: dev
	@echo "-------------------"
	@echo "linting SOURCE_ROOT: ${SOURCE_ROOT} ${TEST_ROOT}"
	@echo "-------------------"
	docker run ${DEV_DOCKER_IMAGE} pylint ${SOURCE_ROOT} --errors-only --jobs 4 ${SOURCE_ROOT} ${TEST_ROOT} --ignored-classes=SQLAlchemy,scoped_session,auto

prod:
	@echo "-------------------"
	@echo "build standalone prod image: ${PROD_DOCKER_IMAGE}"
	@echo "-------------------"
	docker build --file Dockerfile.prod --tag ${PROD_DOCKER_IMAGE} .
