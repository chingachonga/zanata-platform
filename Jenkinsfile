#!/usr/bin/env groovy

node {
  println "look for process-related params"
  sh "env|sort"
  println "running on node ${env.NODE_NAME}"
  sh "ps -eF | grep sleep"
  sh "sleep 24h &"
}