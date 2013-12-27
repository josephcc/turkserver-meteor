unescapeURL = (s) ->
  decodeURIComponent s.replace(/\+/g, "%20")

getURLParams = ->
  params = {}
  m = window.location.href.match(/[\\?&]([^=]+)=([^&#]*)/g)
  if m
    i = 0
    while i < m.length
      a = m[i].match(/.([^=]+)=(.*)/)
      params[unescapeURL(a[1])] = unescapeURL(a[2])
      i++
  return params

params = getURLParams()

loginCallback = (e) ->
  return unless e?
  bootbox.dialog("<p>Unable to login:</p>" + e.message)

mturkLogin = (args) ->
  Accounts.callLoginMethod
    methodArguments: [ args ],
    userCallback: loginCallback

testLogin = ->
  # Don't try logging in if we are logged in or already have parameters
  return if Meteor.userId() or Session.get("_loginParams")

  str = Random.id()
  hitId = str + "_HIT"
  asstId = str + "_Asst"
  workerId = str + "_Worker"
  prompt =
    """<p>TurkServer can create a fake user for testing purposes.</p>
       <p>Press <b>OK</b> to log in with the following credentials, or <b>Cancel</b> to stay logged out.</p>
        <br> HIT id: <b>#{hitId}</b>
        <br> Assignment id: <b>#{asstId}</b>
        <br> Worker id: <b>#{workerId}</b>
    """
  bootbox.confirm prompt, (result) ->
    return unless result
    console.log "Trying login with fake credentials"
    # Save parameters and login
    loginParams = {
      hitId: hitId
      assignmentId: asstId
      workerId: workerId
      test: true
    }
    Session.set("_loginParams", loginParams)
    mturkLogin(loginParams)

Handlebars.registerHelper "hitParams", -> params

Handlebars.registerHelper "hitIsViewing", ->
  params.assignmentId and params.assignmentId is "ASSIGNMENT_ID_NOT_AVAILABLE"

Meteor.startup ->
  # Remember our previous hit parameters unless they have been replaced
  # TODO make sure this doesn't interfere with actual HITs
  if params.hitId and params.assignmentId and params.workerId
    Session.set("_loginParams", {
      hitId: params.hitId
      assignmentId: params.assignmentId
      workerId: params.workerId
    })

  # Recover either page params or stored session params as above
  loginParams = Session.get("_loginParams")

  if loginParams
    mturkLogin(loginParams)
  else
    # TODO we can make sure these test logins maintain parameters as well
    Meteor.defer testLogin, 500

# TODO check that this works properly
Deps.autorun ->
  userId = Meteor.userId()
  return unless userId
  turkserver = Meteor.users.findOne(
    _id: userId
    "turkserver.state": { $exists: true }
  , fields:
    "turkserver.state" : 1
  )?.turkserver
  return unless turkserver

  Session.set("turkserver.state", turkserver.state)

# Reactive variables for state
TurkServer.inLobby = ->
  Session.equals("turkserver.state", "lobby")

# Paths for lobby
Package['iron-router']?.Router.map ->
  @route "lobby",
    template: "tsLobby",
    layoutTemplate: "tsContainer"
