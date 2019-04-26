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

