FROM alpine:3.7

ENV GOVC=https://github.com/vmware/govmomi/releases/download/v0.18.0/govc_linux_amd64.gz
ENV OVA=https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64.ova

RUN apk update && apk add curl bash jq openssh rsync
    
RUN curl -L $GOVC | gunzip > /usr/bin/govc && chmod +x /usr/bin/govc
COPY . /

ADD $OVA /bootstrap.ova
ENTRYPOINT [ "/entrypoint.sh" ]