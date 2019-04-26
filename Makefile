S2I_IMAGE_NAME = s2i-flask
APP_IMAGE_NAME = flask-app
APP_CONT_NAME = flask-demoapp
APP_GIT_REPO = https://github.com/Mad-ness/s2i-demo.git

runapp:
	docker run -d --name $(APP_CONT_NAME) -p 9000:9000/tcp $(APP_IMAGE_NAME)

build_s2i:
	docker build -t $(S2I_IMAGE_NAME) .

build_app: 
	/usr/local/bin/s2i build --context-dir demo-app $(APP_GIT_REPO) $(S2I_IMAGE_NAME) $(APP_IMAGE_NAME)
#	/usr/local/bin/s2i build demo-app/ $(S2I_IMAGE_NAME) $(APP_IMAGE_NAME)

clean:
	docker stop $(APP_CONT_NAME) || true
	docker rm $(APP_CONT_NAME) || true
	docker rmi $(APP_IMAGE_NAME) || true
	docker rmi $(S2I_IMAGE_NAME) || true

