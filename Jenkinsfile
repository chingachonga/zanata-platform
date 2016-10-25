#!/usr/bin/env groovy

// these wrappers don't seem to be built in yet
void ansicolor(Closure<Void> wrapped) {
  wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm', 'defaultFg': 1, 'defaultBg': 2]) {
    wrapped.call()
  }
}
void xvfb(Closure<Void> wrapped) {
  wrap([$class: 'Xvfb']) {
    wrapped.call()
  }
}

void withPorts(Closure<Void> wrapped) {
  def ports = sh(script: 'etc/scripts/allocate-jboss-ports', returnStdout: true)
  withEnv(ports.trim().readLines()) {
    wrapped.call()
  }
}

void printNode() {
  sh "env"
  sh "which chromedriver"
  println "running on node ${env.NODE_NAME}"
}

def notifyStarted() {
  hipchatSend color: "GRAY", notify: true, message: "STARTED: Job <a href=\"${env.BUILD_URL}\">${env.JOB_NAME} #${env.BUILD_NUMBER}</a>"
}

def notifyTestResults(def testType) {
  // if tests have failed currentBuild.result will be 'UNSTABLE'
  if (currentBuild.result != null) {
    hipchatSend color: "YELLOW", notify: true, message: "TESTS FAILED ($testType): Job ${env.JOB_NAME} [${env.BUILD_NUMBER}] (${env.BUILD_URL})"
  } else {
    hipchatSend color: "GREEN", notify: true, message: "TESTS PASSED ($testType): Job ${env.JOB_NAME} [${env.BUILD_NUMBER}] (${env.BUILD_URL})"
  }
}

def notifySuccessful() {
  hipchatSend color: "GRAY", notify: true, message: "SUCCESSFUL: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}] (${env.BUILD_URL})"
}

// TODO try-catch build exception and call this:
def notifyFailed() {
  hipchatSend color: "RED", notify: true, message: "FAILED: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}] (${env.BUILD_URL})"
}

timestamps {
  node {
    ansicolor {
      stage('Checkout') {
        printNode()
        notifyStarted()
        // Checkout code from repository
        // Based on https://issues.jenkins-ci.org/browse/JENKINS-33022?focusedCommentId=248530&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-248530
        // This should be equivalent to checkout scm (noTags: true, shallow: true)

        // TODO use reference repo instead of shallow clone
        // see https://issues.jenkins-ci.org/browse/JENKINS-33273?focusedCommentId=268631&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-268631
        // and https://issues.jenkins-ci.org/browse/JENKINS-33273?focusedCommentId=273644&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-273644

        // this doesn't work on RHEL 7: https://issues.jenkins-ci.org/browse/JENKINS-37229
        // checkout([
        //   $class: 'GitSCM',
        //   branches: scm.branches,
        //   doGenerateSubmoduleConfigurations: scm.doGenerateSubmoduleConfigurations,
        //   extensions: scm.extensions + [[$class: 'CloneOption', noTags: true, reference: '', shallow: true]],
        //   submoduleCfg: [],
        //   userRemoteConfigs: scm.userRemoteConfigs
        // ])
        checkout scm
      }

      stage('Install build tools') {
        printNode()
        // TODO yum install the following
        // Xvfb libaio xorg-x11-server-Xvfb wget unzip git-core
        // https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
        // gcc-c++
        // java-devel; set alternatives for java
        // groovy firefox rpm-build docker
        // download chromedriver

        // Note: if next step happens on another node, mvnw might have to download again
        sh "./mvnw --version"
      }

      // TODO build and archive binaries with unit tests, then in parallel, unarchive and run:
      //   arquillian tests
      //   eap, wildfly functional tests
      //   mysql 5.6, functional tests (on wildfly)
      //   and (later) mariadb 10 functional tests (on wildfly)


      stage('Build') {
        printNode()
        sh """./run-clean.sh mvnw clean package \
                     --batch-mode \
                     --settings .travis-settings.xml \
                     --update-snapshots \
                     -Dmaven.test.failure.ignore \
                     -DstaticAnalysis \
                     -Dchromefirefox \
                     -DskipFuncTests \
                     -DskipArqTests \
-DexcludeFrontend \
        """
// TODO remove -DexcludeFrontend (just for faster testing)

// TODO build zanata-test-war but don't run functional tests (need to modify zanata-test-war pom)

        def testFiles = '**/target/surefire-reports/TEST-*.xml'
        setJUnitPrefix("UNIT", testFiles)
        junit testFiles

        // notify if compile+unit test successful

        notifyTestResults("UNIT")

        archive '**/target/*.war'
//        archive '**/target/*.jar, **/target/*.war'
      }

      stage('stash') {
        stash name: 'workspace', includes: '**'
      }
    }
  }

  stage('Parallel tests') {
    def tasks = [:]
    tasks['Integration tests: WILDFLY'] = {
      node {
        ansicolor {
          unstash 'workspace'
          printNode()
          integrationTests('wildfly8')
        }
      }
    }
    tasks['Integration tests: JBOSSEAP'] = {
      node {
        ansicolor {
          unstash 'workspace'
          printNode()
          integrationTests('jbosseap6')
        }
      }
    }
    tasks.failFast = true
    parallel tasks
  }
  // TODO in case of failure, notify culprits via IRC and/or email
  // https://wiki.jenkins-ci.org/display/JENKINS/Email-ext+plugin#Email-extplugin-PipelineExamples
  // http://stackoverflow.com/a/39535424/14379
  // IRC: https://issues.jenkins-ci.org/browse/JENKINS-33922
  // possible alternatives: Slack, HipChat, RocketChat, Telegram?
  notifySuccessful()
}

def archiveTestResultsIfUnstable() {
  // if tests have failed currentBuild.result will be 'UNSTABLE'
  if (currentBuild.result != null) {
      archive(
        includes: '*/target/**/*.log,*/target/screenshots/**,**/target/site/jacoco/**,**/target/site/xref/**',
        excludes: '**/BACKUP-*.log')
  }
}

def integrationTests(def appserver) {
  xvfb {
    withPorts {
      // Run the maven build
      sh """./run-clean.sh ./mvnw verify \
                   --batch-mode \
                   --settings .travis-settings.xml \
                   -DstaticAnalysis=false \
                   -Dcheckstyle.skip \
                   -Dappserver=$appserver \
                   -Dmaven.test.failure.ignore \
                   -Dmaven.main.skip \
                   -Dgwt.compiler.skip \
                   -Dwebdriver.display=${env.DISPLAY}
                   -Dcargo.debug.jvm.args=
                   -Dwebdriver.type=chrome
                   -Dwebdriver.chrome.driver=/opt/chromedriver
-DexcludeFrontend \
      """
// FIXME put this back
//                   -DallFuncTests \
      // TODO add -Dmaven.war.skip (but we need zanata-test-war)
      // -Dfunctional-test - probably obsolete

      // TODO try to remove webdriver.display cargo.debug.jvm.args webdriver*
    }
  }
  def testFiles = '**/target/failsafe-reports/TEST-*.xml'
  setJUnitPrefix(appserver.toUpperCase(), testFiles)
  junit testFiles
  archiveTestResultsIfUnstable()
  notifyTestResults(appserver.toUpperCase())
}

// from https://issues.jenkins-ci.org/browse/JENKINS-27395?focusedCommentId=256459&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-256459
def setJUnitPrefix(prefix, files) {
  // add prefix to qualified classname
  sh "shopt -s globstar && sed -i \"s/\\(<testcase .*classname=['\\\"]\\)\\([a-z]\\)/\\1${prefix}.\\2/g\" $files"
}
