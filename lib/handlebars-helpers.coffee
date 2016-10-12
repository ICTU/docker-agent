reduceVolumes = (root, volumes, cb) ->
  volumes?.reduce (prev, volume) =>
    parsed = volume.match /^((\/[^:]+)|(\/[^:]+):(\/[^:]+))(:ro|:rw)?(:shared|:do_not_persist)?$/
    if parsed
      cb prev, root, volumes, parsed
    else
      console.error "Invalid volume mapping: #{volume}"
      prev
  , ""

computeExternalPath = (context, parsedPath, service) ->
  [all, ignore, simplePath, mappedPathExt, mappedPathInt, permissions, options] = parsedPath
  if context.storageBucket and options isnt ':do_not_persist'
    basePath = "#{context.dataDir}/#{context.project}/#{context.storageBucket}"
    basePath +=  "/__SHARED__" if options is ':shared'
    if mappedPathExt
       "#{basePath}#{mappedPathExt}"
    else
      "#{basePath}/#{service}#{simplePath}"
  else
    ''

module.exports = (ctx) ->
  literal: (content) -> content
  createVolumes: (data) ->
    reduceVolumes data.data.root, @volumes, (prev, root, volumes, parsed) =>
      dir = computeExternalPath root, parsed, @service
      if dir
        """#{prev}
        mkdir -m 777 -p #{dir}
        """
      else
        prev

  dockervolumes: (data) ->
    reduceVolumes data.data.root, @volumes, (prev, root, volumes, parsed) =>
      [all, ignore, simplePath, mappedPathExt, mappedPathInt, permissions, options] = parsed
      extDir = computeExternalPath root, parsed, @service
      if extDir
        mapping = if mappedPathExt
             "#{extDir}:#{mappedPathInt}"
          else
            "#{extDir}:#{simplePath}"
        "#{prev}-v #{mapping}#{permissions or ''} "
      else
        "#{prev}-v #{simplePath or mappedPathInt}#{permissions or ''} "


  volumesfrom: (data) ->
    root = data.data.root
    volumesFrom = @['volumes-from'] or @['volumes_from']
    volumesFrom?.reduce (prev, volume) ->
      "#{prev}--volumes-from #{volume}-#{root.project}-#{root.instance} "
    , ""

  attribute: attribute = (attrName, attrPrefix) ->
    @[attrName]?.reduce (left, right) =>
      acc = "#{right}".replace /"/g, '\\"'
      "#{left}#{attrPrefix}\"#{acc}\" "
    , ""
  environmentAttributes: ->
    if @environment and Array.isArray @environment
      attribute.call @, 'environment', '-e '
    else
      ("-e '#{key}=#{value}'" for key, value of @environment).join ' '


  mapDocker: ->
    if @mapDocker or @map_docker
      '-v /var/run/docker.sock:/var/run/docker.sock'
    else ''

  syslogUrl: -> ctx.syslogUrl

  eachReverse: (context) ->
    # from: https://github.com/diy/handlebars-helpers/blob/master/lib/each-reverse.js
    options = arguments[arguments.length - 1]
    ret = '';
    if context and context.length > 0
      i = context.length - 1
      while i >= 0
        ret = "#{ret}#{options.fn(context[i])}"
        i--
    else
      ret = options.inverse(this)
    ret

  stringify: JSON.stringify

  dashboardUrl: (data)->
    root = data.data.root
    root.dashboardUrl
