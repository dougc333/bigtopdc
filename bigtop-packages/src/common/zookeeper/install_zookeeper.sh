#!/bin/sh

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -ex

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to zookeeper dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --doc-dir=DIR               path to install docs into [/usr/share/doc/zookeeper]
     --lib-dir=DIR               path to install zookeeper home [/usr/lib/zookeeper]
     --installed-lib-dir=DIR     path where lib-dir will end up on target system
     --bin-dir=DIR               path to install bins [/usr/bin]
     --examples-dir=DIR          path to install examples [doc-dir/examples]
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'doc-dir:' \
  -l 'lib-dir:' \
  -l 'installed-lib-dir:' \
  -l 'bin-dir:' \
  -l 'examples-dir:' \
  -l 'build-dir:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --doc-dir)
        DOC_DIR=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --installed-lib-dir)
        INSTALLED_LIB_DIR=$2 ; shift 2
        ;;
        --bin-dir)
        BIN_DIR=$2 ; shift 2
        ;;
        --examples-dir)
        EXAMPLES_DIR=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in PREFIX BUILD_DIR ; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

MAN_DIR=$PREFIX/usr/share/man/man1
DOC_DIR=${DOC_DIR:-/usr/share/doc/zookeeper}
LIB_DIR=${LIB_DIR:-/usr/lib/zookeeper}
INSTALLED_LIB_DIR=${INSTALLED_LIB_DIR:-/usr/lib/zookeeper}
BIN_DIR=${BIN_DIR:-/usr/bin}
CONF_DIR=/etc/zookeeper/conf
CONF_DIST_DIR=/etc/zookeeper/conf.dist/

install -d -m 0755 $PREFIX/$LIB_DIR/
rm build/zookeeper-*-javadoc.jar
rm build/zookeeper-*-bin.jar
rm build/zookeeper-*-sources.jar
cp build/zookeeper*.jar $PREFIX/$LIB_DIR/

# Make a symlink of zookeeper.jar to zookeeper-version.jar
for x in build/zookeeper*jar ; do
  x=$(basename $x)
  ln -s $x $PREFIX/$LIB_DIR/zookeeper.jar
done
  

install -d -m 0755 $PREFIX/$LIB_DIR/lib
cp build/lib/*.jar $PREFIX/$LIB_DIR/lib

# Copy in the configuration files
install -d -m 0755 $PREFIX/$CONF_DIST_DIR
cp zoo.cfg conf/* $PREFIX/$CONF_DIST_DIR/
ln -s $CONF_DIR $PREFIX/$LIB_DIR/conf

# FIXME:
cat << __EOT__ >> $PREFIX/$CONF_DIST_DIR/log4j.properties
# Define some default values that can be overridden by system properties
zookeeper.root.logger=INFO, CONSOLE
zookeeper.console.threshold=INFO
zookeeper.log.dir=.
zookeeper.log.file=zookeeper.log
zookeeper.log.threshold=DEBUG
zookeeper.tracelog.dir=.
zookeeper.tracelog.file=zookeeper_trace.log

log4j.appender.ROLLINGFILE.File=\${zookeeper.log.dir}/\${zookeeper.log.file}
log4j.rootLogger=\${zookeeper.root.logger}
__EOT__

# Copy in the /usr/bin/zookeeper-server wrapper
install -d -m 0755 $PREFIX/$LIB_DIR/bin

for i in zkServer.sh zkEnv.sh zkCli.sh zkCleanup.sh
	do cp bin/$i $PREFIX/$LIB_DIR/bin
	chmod 755 $PREFIX/$LIB_DIR/bin/$i
done

wrapper=$PREFIX/usr/bin/zookeeper-client
install -d -m 0755 `dirname $wrapper`
cat > $wrapper <<EOF
#!/bin/sh

# Autodetect JAVA_HOME if not defined
if [ -e /usr/libexec/bigtop-detect-javahome ]; then
  . /usr/libexec/bigtop-detect-javahome
elif [ -e /usr/lib/bigtop-utils/bigtop-detect-javahome ]; then
  . /usr/lib/bigtop-utils/bigtop-detect-javahome
fi

export ZOOKEEPER_HOME=\${ZOOKEEPER_CONF:-/usr/lib/zookeeper}
export ZOOKEEPER_CONF=\${ZOOKEEPER_CONF:-/etc/zookeeper/conf}
export CLASSPATH=\$CLASSPATH:\$ZOOKEEPER_CONF:\$ZOOKEEPER_HOME/*:\$ZOOKEEPER_HOME/lib/*
export ZOOCFGDIR=\${ZOOCFGDIR:-\$ZOOKEEPER_CONF}
env CLASSPATH=\$CLASSPATH /usr/lib/zookeeper/bin/zkCli.sh "\$@"
EOF
chmod 755 $wrapper

wrapper=$PREFIX/usr/bin/zookeeper-server
cat > $wrapper <<EOF
#!/bin/sh

# Autodetect JAVA_HOME if not defined
if [ -e /usr/libexec/bigtop-detect-javahome ]; then
  . /usr/libexec/bigtop-detect-javahome
elif [ -e /usr/lib/bigtop-utils/bigtop-detect-javahome ]; then
  . /usr/lib/bigtop-utils/bigtop-detect-javahome
fi

export ZOOPIDFILE=\${ZOOPIDFILE:-/var/run/zookeeper/zookeeper-server.pid}
export ZOOKEEPER_HOME=\${ZOOKEEPER_CONF:-/usr/lib/zookeeper}
export ZOOKEEPER_CONF=\${ZOOKEEPER_CONF:-/etc/zookeeper/conf}
export ZOOCFGDIR=\${ZOOCFGDIR:-\$ZOOKEEPER_CONF}
export CLASSPATH=\$CLASSPATH:\$ZOOKEEPER_CONF:\$ZOOKEEPER_HOME/*:\$ZOOKEEPER_HOME/lib/*
export ZOO_LOG_DIR=/var/log/zookeeper
export ZOO_LOG4J_PROP=INFO,ROLLINGFILE
export JVMFLAGS=-Dzookeeper.log.threshold=INFO
env CLASSPATH=\$CLASSPATH /usr/lib/zookeeper/bin/zkServer.sh "\$@"
EOF
chmod 755 $wrapper

# Copy in the docs
install -d -m 0755 $PREFIX/$DOC_DIR
cp -a $BUILD_DIR/docs/* $PREFIX/$DOC_DIR
cp *.txt $PREFIX/$DOC_DIR/

install -d -m 0755 $MAN_DIR
gzip -c zookeeper.1 > $MAN_DIR/zookeeper.1.gz

# Zookeeper log and tx log directory
install -d -m 1766 $PREFIX/var/log/zookeeper
install -d -m 1766 $PREFIX/var/log/zookeeper/txlog
