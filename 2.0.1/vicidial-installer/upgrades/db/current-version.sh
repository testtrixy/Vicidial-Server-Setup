#!/usr/bin/env bash

asterisk -V | awk '{print $2}'
