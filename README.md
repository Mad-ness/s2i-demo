# Lab. Using S2I tool

This lab demonstrates usage of __S2I__ tool. The repo is https://github.com/Mad-ness/s2i-demo.

## Prerequisites

* The lab should be done on a linux host with running _docker_ service.
* A Docker registry should exist and the client should be able to pull and push images from/to it.

* ___S2I___ tool should be downloaded and put into _$HOME_ directory:

```
$ curl -sLo - https://github.com/openshift/source-to-image/releases/download/v1.1.13/source-to-image-v1.1.13-b54d75d3-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf -
$ ls -l /usr/local/bin/s2i
-rwxr-xr-x. 1 demo demo 7271680 Dec 11 18:26 /usr/local/bin/s2i
```

* Copy all files from this directory to $HOME/lab-s2i-tool


Perform all further actions in __$HOME/lab-s2i-tool__ directory.


## Phase 1: Preparing S2I scripts


Make sure that all scripts in _s2i/bin_ directory has the execute bit enabled (`chmod a+x s2i/bin/*`).

### Script s2i/bin/run

This script is executed to run the application.

```bash
#!/bin/bash

export FLASK_APP=main.py
exec flask run --with-threads --debugger -h 0.0.0.0 -p $LISTEN_PORT

exit 0
```

### Script s2i/bin/assemble

This script is executed when the image on the second stage - building an app image. The current context is  __app/__ directory as it will be used in __s2i build__ command below, so all files should be referenced inside this directory.

The script deploys the application from provided sources in _/tmp/src_. It should make sure that all files are installed in the needed directories, all configuration settings are made.

```bash
#!/bin/bash -e

# By default S2I places the application source in
# {io.openshift.s2i.destination}/src directory
# Where io.openshift.s2i.destination is the label defined on the image
# and it defaults to /tmp

echo ">>> Installing application source"
pushd /tmp/src
ls -l
find . -type f | xargs -I % install -D % /opt/app-root/%
popd
echo ">>> Installation completed"

exit 0
```

### Script s2i/bin/usage

This script shows the basic information on how to use this image. Put all needed information here to tell about this.
Check the __Dockerfile__ below to see how the script is called.

```bash
#!/bin/bash

cat << EOF

This is the S2I demo image that runs a Flask application.
To use it, install S2I: https://github.com/openshift/source-to-image

Sample invocation:
  s2i build https://github.com/Mad-ness/s2i-demo.git --context-dir=demo-app python:3 flask-app

You can then run the resulting image via:
  docker run -p 9000:9000 flask-app

EOF

exit 0
```

### Script s2i/bin/save-artifacts

Use this script if you need to save some artifacts between builds. Later they can be used repeatedly in the __assemble__ script to speed up new roll outs.

```bash
#!/bin/bash

exit 0
```


### File config/requirements.txt

This file describes python dependencies needed for the __Flask__ applications. Those dependencies will be installed by calling `pip install -r requirements.txt` in the __Dockerfile__.

```
Flask==1.0.2
```

### Dockerfile

The image built from this _Dockerfile_ will be a _builder image_. It uses base image ___python:3___ as it already includes Python. Pay attention on the labels.

```dockerfile
FROM        python:3
LABEL       maintainer.name="Dmitrii Mostovshchikov" \
            maintainer.email="Dmitrii.Mostovshchikov@li9.com" \
            maintainer.company="Li9, Inc." \
            company.website="https://www.li9.com" \
            io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
            io.openshift.tags="python,flask,example" \
            io.k8s.description="Example application written on Python and run by Flask" \
            io.openshift.non-scalable="false" \
            io.openshift.min-memory="128Mi" \
            io.openshift.min-cpu="100m" \
            io.openshift.s2i.destination="/tmp"
ENV         LISTEN_PORT 9000
WORKDIR     /opt/app-root

ADD         ./s2i/bin                 /usr/libexec/s2i
ADD         ./config/requirements.txt /opt/app-root
RUN         pip install --no-cache-dir -r /opt/app-root/requirements.txt

EXPOSE      ${LISTEN_PORT}/tcp

# If someone runs the container the Usage will be displayed then
CMD         [ "/usr/libexec/s2i/usage" ]
```

The __Dockerfile__ should have the label `io.openshift.s2i.scripts-url="image:///usr/libexec/s2i"` which indicates where S2I scrips are located.

## Application

The application consists of a single python script which runs some functions as a __Flask__ application.

```
$ cat demo-app/main.py
```

```python
#!/usr/bin/env python

import platform

from flask import Flask, render_template

app = Flask(__name__)

@app.errorhandler(404)
def page_404(e):
  return render_template('page_404.html'), 404


@app.route("/")
def hello(): return "Hello, World!"


@app.route("/ping")
def ping(): return "pong"


@app.route("/healthz")
def healthz(): return "ok"


@app.route("/version")
def version():
  info = dict()
  info['architecture'] = platform.architecture()
  info['distribution'] = platform.linux_distribution()
  info['machine'] = platform.machine()
  info['nodename'] = platform.node()
  info['processor'] = platform.processor()
  info['system'] = platform.system()
  return str(info)
```

And also includes a template file *demo-app/templates/page_404.html* needed to the application.


## Phase 2: Building the building image

In order to automate all routine operations, there is _Makefile_ which calls all needed commands

```
$ cat Makefile
```
```makefile
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
```

There are two lines in __build_app__ section which you can use, one line at a time:
- first line uses sources of application from a github repository. We also need to tell in which directory the sources should be taken from. All files then will be downloaded automatically:
```
/usr/local/bin/s2i build --context-dir demo-app $(APP_GIT_REPO) $(S2I_IMAGE_NAME) $(APP_IMAGE_NAME)
```
- second line allows us to use a local directory `demo-app/`
```
/usr/local/bin/s2i build demo-app/ $(S2I_IMAGE_NAME) $(APP_IMAGE_NAME)
```

Now we are ready to create an __SI2 image__.

* Build the image __frontend-s2i__. Just run `make build_s2i` or do the same by calling directly the command from the _Makefile_ `docker build -t s2i-flask .`:

```
docker build -t s2i-flask .
Sending build context to Docker daemon 28.16 kB
Step 1/9 : FROM python:3
 ---> 954987809e63
Step 2/9 : LABEL maintainer.name "Dmitrii Mostovshchikov" maintainer.email "Dmitrii.Mostovshchikov@li9.com" maintainer.company "Li9, Inc." company.website "https://www.li9.com" io.openshift.s2i.scripts-url "image:///usr/libexec/s2i" io.openshift.tags "python,flask,example" io.k8s.description "Example application written on Python and run by Flask" io.openshift.non-scalable "false" io.openshift.min-memory "128Mi" io.openshift.min-cpu "100m" io.openshift.s2i.destination "/tmp"
 ---> Running in dd77bdd1ce1d
 ---> 98ec753c4d59
Removing intermediate container dd77bdd1ce1d
Step 3/9 : ENV LISTEN_PORT 9000
 ---> Running in d5ce8bafca63
 ---> a7e3ec8259a9
Removing intermediate container d5ce8bafca63
Step 4/9 : WORKDIR /opt/app-root
 ---> ec1609fb757d
Removing intermediate container ab7fb3d190c8
Step 5/9 : ADD ./s2i/bin /usr/libexec/s2i
 ---> 9674b60f8a7a
Removing intermediate container 8e67712764e2
Step 6/9 : ADD ./config/requirements.txt /opt/app-root
 ---> d349d482c132
Removing intermediate container 0f4601d958ec
Step 7/9 : RUN pip install --no-cache-dir -r /opt/app-root/requirements.txt
 ---> Running in 79ac2433f9ba

Collecting Flask==1.0.2 (from -r /opt/app-root/requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/7f/e7/08578774ed4536d3242b14dacb4696386634607af824ea997202cd0edb4b/Flask-1.0.2-py2.py3-none-any.whl (91kB)
Collecting Werkzeug>=0.14 (from Flask==1.0.2->-r /opt/app-root/requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/18/79/84f02539cc181cdbf5ff5a41b9f52cae870b6f632767e43ba6ac70132e92/Werkzeug-0.15.2-py2.py3-none-any.whl (328kB)
Collecting Jinja2>=2.10 (from Flask==1.0.2->-r /opt/app-root/requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/1d/e7/fd8b501e7a6dfe492a433deb7b9d833d39ca74916fa8bc63dd1a4947a671/Jinja2-2.10.1-py2.py3-none-any.whl (124kB)
Collecting click>=5.1 (from Flask==1.0.2->-r /opt/app-root/requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/fa/37/45185cb5abbc30d7257104c434fe0b07e5a195a6847506c074527aa599ec/Click-7.0-py2.py3-none-any.whl (81kB)
Collecting itsdangerous>=0.24 (from Flask==1.0.2->-r /opt/app-root/requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/76/ae/44b03b253d6fade317f32c24d100b3b35c2239807046a4c953c7b89fa49e/itsdangerous-1.1.0-py2.py3-none-any.whl
Collecting MarkupSafe>=0.23 (from Jinja2>=2.10->Flask==1.0.2->-r /opt/app-root/requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/98/7b/ff284bd8c80654e471b769062a9b43cc5d03e7a615048d96f4619df8d420/MarkupSafe-1.1.1-cp37-cp37m-manylinux1_x86_64.whl
Installing collected packages: Werkzeug, MarkupSafe, Jinja2, click, itsdangerous, Flask
Successfully installed Flask-1.0.2 Jinja2-2.10.1 MarkupSafe-1.1.1 Werkzeug-0.15.2 click-7.0 itsdangerous-1.1.0
 ---> 0365ef34c57a
Removing intermediate container 79ac2433f9ba
Step 8/9 : EXPOSE ${LISTEN_PORT}/tcp
 ---> Running in 9d5e97f76483
 ---> e4b92afdd723
Removing intermediate container 9d5e97f76483
Step 9/9 : CMD /usr/libexec/s2i/usage
 ---> Running in 3100d327d3b9
 ---> c2c1ee05803a
Removing intermediate container 3100d327d3b9
Successfully built c2c1ee05803a
```

Right now the image named s2i-flask is a ready __S2I__ image. Such S2I images are shipped a lot within OpenShift.


Now we are ready deploy our application to this S2I image

## Phase 3. Building the app-ready image

To build an app-ready image run a make command `make build_app` or do the same by running directly s2i command `/usr/local/bin/s2i build --context-dir demo-app https://github.com/Mad-ness/s2i-demo.git s2i-flask flask-app`

At this run __S2I__ performs following actions:
- run a container from __s2i-flask__ image
- copies files from `demo-app` directory to the image, to `/tmp` directory
- calls the script `/usr/libexec/s2i/bin/assemble`
- creates a new image called `flask-app`

```
$ make build_app
```
```
/usr/local/bin/s2i build --context-dir demo-app https://github.com/Mad-ness/s2i-demo.git s2i-flask flask-app
>>> Installing application source
/tmp/src /opt/app-root
total 4
-rw-r--r--. 1 root root 682 Apr 26 18:02 main.py
drwxr-xr-x. 2 root root  27 Apr 26 18:02 templates
/opt/app-root
>>> Installation completed
Build completed successfully
```

After this command completed successfully the image ___flask-app___ can be used for running our application.

## Verification

* Run an application container from the app image `docker run -d --name flask-demoapp -p 9000:9000/tcp flask-app` (we can also use `make runapp`)

```
$ sudo make runapp
docker run -d --name flask-demoapp -p 9000:9000/tcp flask-app
c819f3b7e09ffe5d3029e07566a43560efeadfc2180f722abce4664ae1ebb421
```

* And check that the application is responding on the requests

```
$ for  url in / /ping /healthz /version /badpage; do curl 127.0.0.1:9000${url}; echo; done
Hello, World!
pong
ok
{'architecture': ('64bit', ''), 'distribution': ('debian', '9.8', ''), 'machine': 'x86_64', 'nodename': 'c819f3b7e09f', 'processor': '', 'system': 'Linux'}
<html>
<title>Page not found, 404</title>
<body>
Such URL is not implemented
</body>
</html>
```

## Cleaning up

Clean up after youself

```shell
$ sudo make clean
docker stop flask-demoapp || true
flask-demoapp
docker rm flask-demoapp || true
flask-demoapp
docker rmi flask-app || true
Untagged: flask-app:latest
Deleted: sha256:2a128c76ef26dde3f53dc0bb6d521cf1090b8687f38cf6bea2bdb89701bc9a20
Deleted: sha256:8e20b2ee0419ce71e970b32c970543e183ae44e8daefb53439992fc010f1f8c3
docker rmi s2i-flask || true
Untagged: s2i-flask:latest
Deleted: sha256:e51e15cb85b8e21024324b81876555a8666b30097d3f4c45630cf35c7903ff86
Deleted: sha256:e2ad80b4778aa640ab7c97af54f24b89dab89b8f990d4fcfb69658d54f132f39
Deleted: sha256:e0fb3d0b9320a01b5c7d9cf36c67ca0d887027dd2413fbc0d17ceb34e011ce9a
Deleted: sha256:4fce145c8a41bccffe8e0d8e58d52e771f9b98ba54df400caa2a9d699df179a4
Deleted: sha256:e58299bd4ae73126bacbb6d71613c55cb009cb70eadc76ffafa07a66a93c637f
Deleted: sha256:91f81f72ae19e6d80cfb0f5c403322961ea38c79edb4dcca37cc56895cf158eb
Deleted: sha256:11df9bc38fc53b9536891ab3c32d35a4fe91852b777ea938d64af8309bce3534
Deleted: sha256:8af4ac69fab1e60e25dbf79d561ae4fb91feae51911db6c5b31dbbe887e30893
Deleted: sha256:55be05f9ea15ec3bac8e71e01911564d1aaf2da90358d661843cab7ea2c3d8ea
Deleted: sha256:090802ddb25ab48759c11137a71b28be6e6fed3ea3868912e2f83fa5a0c0c009
Deleted: sha256:c1d6eafa36d29635229692bf03f895336ab1768930733fd21007523c4a928114
Deleted: sha256:b2ebf8b22587181463044471a4a9785310b62f86941a7233fd9b519d71c0a7f4
```


## Authors

- Dmitrii Mostovshchikov <Dmitrii.Mostovshchikov@li9.com>

