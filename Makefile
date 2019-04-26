S2I_IMAGE_NAME = s2i-flask
APP_IMAGE_NAME = flask-app
APP_CONT_NAME = flask-demoapp

runapp:
	docker run -d --name $(APP_CONT_NAME) -p 9000:9000/tcp $(APP_IMAGE_NAME)

build_s2i:
	docker build -t $(S2I_IMAGE_NAME) .

build_app: build_s2i
	/usr/local/bin/s2i build demo-app/ $(S2I_IMAGE_NAME) $(APP_IMAGE_NAME)

clean:
	docker stop $(APP_CONT_NAME) || true
	docker rm $(APP_CONT_NAME) || true
	docker rmi $(APP_IMAGE_NAME) || true
	docker rmi $(S2I_IMAGE_NAME) || true

