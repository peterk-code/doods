EXECUTABLE := doods
GITVERSION := $(shell git describe --dirty --always --tags --long)
GOPATH ?= ${HOME}/go
PACKAGENAME := $(shell go list -m -f '{{.Path}}')
TOOLS := ${GOPATH}/src/github.com/gogo/protobuf/proto \
	${GOPATH}/bin/protoc-gen-gogoslick \
	${GOPATH}/bin/protoc-gen-grpc-gateway \
	${GOPATH}/bin/protoc-gen-swagger
export PROTOBUF_INCLUDES = -I. -I/usr/include -I${GOPATH}/src -I$(shell go list -e -f '{{.Dir}}' .) -I$(shell go list -e -f '{{.Dir}}' github.com/grpc-ecosystem/grpc-gateway/runtime)/../third_party/googleapis
PROTOS := ./server/rpc/version.pb.gw.go \
	./odrpc/rpc.pb.gw.go

.PHONY: default
default: ${EXECUTABLE}

# This is all the tools required to compile, test and handle protobufs
tools: ${TOOLS}

${GOPATH}/src/github.com/gogo/protobuf/proto:
	GO111MODULE=off go get github.com/gogo/protobuf/proto

${GOPATH}/bin/protoc-gen-gogoslick:
	go get github.com/gogo/protobuf/protoc-gen-gogoslick

${GOPATH}/bin/protoc-gen-grpc-gateway:
	go get github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway

${GOPATH}/bin/protoc-gen-swagger:
	go get github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger

# Handle all grpc endpoint protobufs
%.pb.gw.go: %.proto
	protoc ${PROTOBUF_INCLUDES} --gogoslick_out=paths=source_relative,plugins=grpc:. --grpc-gateway_out=paths=source_relative,logtostderr=true:. --swagger_out=logtostderr=true:. $*.proto

# Handle any non-specific protobufs
%.pb.go: %.proto
	protoc ${PROTOBUF_INCLUDES} --gogoslick_out=paths=source_relative,plugins=grpc:. $*.proto

.PHONY: ${EXECUTABLE}
${EXECUTABLE}: tools ${PROTOS}
	# Compiling...
	go build -ldflags "-X ${PACKAGENAME}/conf.Executable=${EXECUTABLE} -X ${PACKAGENAME}/conf.GitVersion=${GITVERSION}" -o ${EXECUTABLE}

.PHONY: test
test: tools ${PROTOS}
	go test -cover ./...

.PHONY: deps
deps:
	# Fetching dependancies...
	go get -d -v # Adding -u here will break CI

docker-builder: Dockerfile_builder
	docker build -t snowzach/doods:builder -f Dockerfile_builder .

docker:
	docker build -t snowzach/doods:latest .

buildenv: docker-builder
	$(eval USBDEVICE := $(shell if [ -x /dev/bus/usb ]; then echo '--device /dev/bus/usb'; fi))
	docker run -it -v ${PWD}:/build ${USBDEVICE} -p 8900:8080 snowzach/doods:builder