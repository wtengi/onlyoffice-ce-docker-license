ARG product_version=7.1.1

ARG build_number=23
ARG oo_root='/var/www/onlyoffice/documentserver'

## Setup
FROM onlyoffice/documentserver:${product_version}.${build_number} as setup-stage
ARG product_version
ARG build_number
ARG oo_root

ENV PRODUCT_VERSION=${product_version}
ENV BUILD_NUMBER=${build_number}

ARG build_deps="git make g++ nodejs npm"
RUN apt-get update && apt-get install -y ${build_deps}
RUN npm install -g pkg grunt grunt-cli

WORKDIR /build

## Clone
FROM setup-stage as clone-stage

ARG tag=v${PRODUCT_VERSION}.${BUILD_NUMBER}

RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/build_tools.git /build/build_tools
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/sdkjs.git       /build/sdkjs
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/web-apps.git    /build/web-apps
RUN git clone --quiet --branch $tag --depth 1 https://github.com/ONLYOFFICE/server.git      /build/server

COPY server-org.patch /build/
COPY web-apps-rw.patch /build/


RUN cd /build/server   && git apply -v --whitespace=warn /build/server-org.patch
RUN cd /build/web-apps && git apply -v --whitespace=warn /build/web-apps-rw.patch

## Build
FROM clone-stage as build-stage

# build server with license checks patched
WORKDIR /build/server
RUN make
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/FileConverter -t node14-linux -o /build/converter
RUN pkg /build/build_tools/out/linux_64/onlyoffice/documentserver/server/DocService -t node14-linux --options max_old_space_size=4096 -o /build/docservice

# build web-apps with mobile editing
WORKDIR /build/web-apps/build
RUN npm install
RUN grunt 
RUN ls

## Final image
FROM onlyoffice/documentserver:${product_version}.${build_number}
ARG oo_root

# server
COPY --from=build-stage /build/converter  ${oo_root}/server/FileConverter/converter
COPY --from=build-stage /build/docservice ${oo_root}/server/DocService/docservice

# web-apps
COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/documenteditor/main/app.js     ${oo_root}/web-apps/apps/documenteditor/mobile/main/app.js
COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/documenteditor/mobile/dist/js/app.js     ${oo_root}/web-apps/apps/documenteditor/mobile/dist/js/app.js
COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/presentationeditor/main/app.js ${oo_root}/web-apps/apps/presentationeditor/main/app.js
COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/presentationeditor/mobile/dist/js/app.js ${oo_root}/web-apps/apps/presentationeditor/mobile/dist/js/app.js
COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/spreadsheeteditor/main/app.js  ${oo_root}/web-apps/apps/spreadsheeteditor/mobile/main/app.js
COPY --from=build-stage /build/web-apps/deploy/web-apps/apps/spreadsheeteditor/mobile/dist/js/app.js  ${oo_root}/web-apps/apps/spreadsheeteditor/mobile/dist/js/app.js
