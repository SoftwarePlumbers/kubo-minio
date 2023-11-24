FROM almalinux:9.2 AS common_runtime
COPY etc/yum.repos.d/oneAPI.repo /etc/yum.repos.d
COPY etc/pki/ca-trust/source/anchors/galifrey.pem /etc/pki/ca-trust/source/anchors/galifrey.pem
RUN update-ca-trust
RUN yum install -y findutils 
RUN yum install -y jq hwloc pkgconfig llvm wget intel-oneapi-runtime-opencl intel-oneapi-runtime-compilers intel-oneapi-runtime-compilers-32bit
RUN ln -s /usr/lib64/libhwloc.so.15.2.0 /usr/lib64/libhwloc.so
ENV IPFS_PATH /data/ipfs
RUN mkdir -p $IPFS_PATH \
  && adduser -d $IPFS_PATH -u 1000 -G users ipfs \
  && chown ipfs:users $IPFS_PATH
VOLUME $IPFS_PATH

FROM common_runtime AS builder
RUN yum install -y git make golang clang  
COPY etc/profile.d/go.sh /etc/profile.d/go.sh
ENV GO_TAR go1.21.4.linux-amd64.tar.gz
ENV CGO_ENABLED 1
ENV GO111MODULE on
ADD https://go.dev/dl/$GO_TAR /usr/local
RUN cd /usr/local; tar -xf $GO_TAR; rm $GO_TAR
RUN mkdir /build
WORKDIR /build
RUN git clone https://github.com/ipfs/kubo.git
WORKDIR /build/kubo
RUN git checkout v0.23.0
RUN go get github.com/ipfs/go-ds-s3/plugin@v0.9.0
RUN echo -en "\ns3ds github.com/ipfs/go-ds-s3/plugin 0" >> plugin/loader/preload_list
RUN make build

FROM common_runtime AS init_container
COPY --from=builder /build/kubo/cmd/ipfs/ipfs /usr/local/bin/ipfs
COPY bin/init.sh /usr/local/bin/init.sh
# Note the init script should run as root so that it can chown the volume
ENTRYPOINT ["/bin/bash"]
CMD ["/usr/local/bin/init.sh"]

FROM common_runtime AS runContainer
COPY --from=builder /build/kubo/cmd/ipfs/ipfs /usr/local/bin/ipfs
USER ipfs
# Swarm TCP; should be exposed to the public
EXPOSE 4001
# Swarm UDP; should be exposed to the public
EXPOSE 4001/udp
# Daemon API; must not be exposed publicly but to client services under you control
EXPOSE 5001
# Web Gateway; can be exposed publicly with a proxy, e.g. as https://ipfs.example.org
EXPOSE 8080
# Swarm Websockets; must be exposed publicly when the node is listening using the websocket transport (/ipX/.../tcp/8081/ws).
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ipfs dag stat /ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn || exit 1
ENTRYPOINT ["/usr/local/bin/ipfs"]
CMD ["daemon", "--migrate=true", "--agent-version-suffix=docker"]
