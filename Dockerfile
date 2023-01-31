FROM rockylinux:8.5
COPY etc/yum.repos.d/oneAPI.repo /etc/yum.repos.d
COPY etc/profile.d/go.sh /etc/profile.d/go.sh
RUN yum install -y findutils 
RUN yum install -y git make jq golang hwloc gcc pkgconfig clang llvm wget intel-oneapi-runtime-opencl intel-oneapi-runtime-compilers intel-oneapi-runtime-compilers-32bit
RUN ln -s /usr/lib64/libhwloc.so.15.2.0 /usr/lib64/libhwloc.so
ADD https://go.dev/dl/go1.18.1.linux-amd64.tar.gz /usr/local
RUN cd /usr/local; tar -xf go1.18.1.linux-amd64.tar.gz; rm go1.18.1.linux-amd64.tar.gz
ENTRYPOINT ["/bin/bash"]
