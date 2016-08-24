reduceVolumes = (root, volumes, cb) ->
  volumes?.reduce (prev, volume) =>
    parsed = volume.match /^((\/[^:]+)|(\/[^:]+):(\/[^:]+))(:ro|:rw)?(:shared|:do_not_persist)?$/
    if parsed
      cb prev, root, volumes, parsed
    else
      console.error "Invalid volume mapping: #{volume}"
      prev
  , ""

module.exports = (ctx) ->
  literal: (content) -> content
  createVolumes: (data) ->
    reduceVolumes data.data.root, @volumes, (prev, root, volumes, parsed) =>
      [all, ignore, simplePath, mappedPathExt, mappedPathInt, permissions, options] = parsed
      if root.storageBucket and options isnt ':do_not_persist'
        basePath = if options is ':shared'
            "#{root.sharedDataDir}/#{root.project}"
          else
            "#{root.dataDir}/#{root.project}/#{root.storageBucket}"
        dir = if mappedPathExt
             "#{basePath}/#{@service}#{mappedPathExt}"
          else
            "#{basePath}/#{@service}#{simplePath}"
        """#{prev}
        mkdir -m 777 -p #{dir}
        """
      else
        """#{prev}
        """

  dockervolumes: (data) ->
    reduceVolumes data.data.root, @volumes, (prev, root, volumes, parsed) =>
      [all, ignore, simplePath, mappedPathExt, mappedPathInt, permissions, options] = parsed
      if root.storageBucket and options isnt ':do_not_persist'
        basePath = if options is ':shared'
            "#{root.sharedDataDir}/#{root.project}"
          else
            "#{root.dataDir}/#{root.project}/#{root.storageBucket}"
        mapping = if mappedPathExt
             "#{basePath}/#{@service}#{mappedPathExt}:#{mappedPathInt}"
          else
            "#{basePath}/#{@service}#{simplePath}"
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


  mapDocker: (context) ->
    console.log 'mapDocker', @, context
    if context.mapDocker or context.map_docker
      context.fn(this)
    else context.inverse(this)

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
