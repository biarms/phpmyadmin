# Brothers in ARMs' phpMyAdmin docker image

![GitHub release (latest by date)](https://img.shields.io/github/v/release/biarms/phpmyadmin?label=Latest%20Github%20release&logo=Github)
![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/biarms/phpmyadmin?include_prereleases&label=Highest%20GitHub%20release&logo=Github&sort=semver)

[![TravisCI build status image](https://img.shields.io/travis/biarms/phpmyadmin/master?label=Travis%20build&logo=Travis)](https://travis-ci.org/biarms/phpmyadmin)
[![CircleCI build status image](https://img.shields.io/circleci/build/gh/biarms/phpmyadmin/master?label=CircleCI%20build&logo=CircleCI)](https://circleci.com/gh/biarms/phpmyadmin)

[![Docker Pulls image](https://img.shields.io/docker/pulls/biarms/phpmyadmin?logo=Docker)](https://hub.docker.com/r/biarms/phpmyadmin)
[![Docker Stars image](https://img.shields.io/docker/stars/biarms/phpmyadmin?logo=Docker)](https://hub.docker.com/r/biarms/phpmyadmin)
[![Highest Docker release](https://img.shields.io/docker/v/biarms/phpmyadmin?label=docker%20release&logo=Docker&sort=semver)](https://hub.docker.com/r/biarms/phpmyadmin)

<!--
[![Travis build status](https://api.travis-ci.org/biarms/phpmyadmin.svg?branch=master)](https://travis-ci.org/biarms/phpmyadmin) 
[![CircleCI build status](https://circleci.com/gh/biarms/phpmyadmin.svg?style=svg)](https://circleci.com/gh/biarms/phpmyadmin)
-->

## Overview
This git repo build the official phpmyadmin docker image, but on ARM devices.

Resulting docker images are pushed on [dockerhub](https://hub.docker.com/r/biarms/phpmyadmin/).

The documentation of https://github.com/phpmyadmin/docker (as well as https://hub.docker.com/r/phpmyadmin/phpmyadmin/) should also be applicable to this image.

## How to build locally
1. Option 1: with CircleCI Local CLI:
   - Install [CircleCI Local CLI](https://circleci.com/docs/2.0/local-cli/)
   - Call `circleci local execute`
2. Option 2: with make:
   - Install [GNU make](https://www.gnu.org/software/make/manual/make.html). Version 3.81 (which came out-of-the-box on MacOS) should be OK.
   - Call `make build`
