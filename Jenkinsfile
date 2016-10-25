#!/usr/bin/env groovy

node ('master') {
  println "running on node ${env.NODE_NAME}"
  // sh "ps -eF | grep sleep"
  def ppid = sh returnStdout: true, script: 'ps -o ppid= $$'

  println "check the process tree for sleep"
  sh "sleep 1h"
}
