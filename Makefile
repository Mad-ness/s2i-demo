IMAGE_NAME = flaskapp
S2I_IMAGE = flaskprod
FLASK_ID = flask-instance

run:
	docker run -d --name ${FLASK_ID} -p 9000:9000 ${S2I_IMAGE}


.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .

s2i-build:
	/usr/local/bin/s2i build source/ ${IMAGE_NAME} ${S2I_IMAGE}

buildall: build s2i-build


.PHONY: test

# Build the candidate image, run a container from it
# and test it.
# If all tests pass then tag image as $(IMAGE_NAME)
test:
	docker build -t $(IMAGE_NAME)-candidate .
	docker run --rm --name $(IMAGE_NAME)-qa $(IMAGE_NAME)-candidate 
	docker rmi $(IMAGE_NAME)-candidate 

clean-s2i:
	docker stop ${FLASK_ID}
	docker rmi ${S2I_IMAGE}

clean:
	docker stop ${FLASK_ID} || true
	docker rm ${FLASK_ID} || true
	docker rmi -f ${S2I_IMAGE} ${IMAGE_NAME} $(IMAGE_NAME)-candidate || true


