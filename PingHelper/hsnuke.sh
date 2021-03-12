#!/bin/bash
pkill -9 'Hearthstone'
pkill -9 'Battle\.net'
while ! open /Applications/Battle.net.app; do sleep 0.1; done
