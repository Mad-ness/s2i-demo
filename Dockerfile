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
ADD         ./source/                 /opt/app-root
ADD         ./config/requirements.txt /opt/app-root
RUN         pip install --no-cache-dir -r /opt/app-root/requirements.txt

EXPOSE      ${LISTEN_PORT}/tcp

# If someone runs the container the Usage will be displayed then
CMD         [ "/usr/libexec/s2i/usage" ]

