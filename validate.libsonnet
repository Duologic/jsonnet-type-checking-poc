{
  local root = self,

  local trace(result, object, message) =
    if result
    then true
    else std.trace('ERR %s: \n%s' % [message, std.manifestJson(object)], false),

  validate(object, schema)::
    if std.isBoolean(schema)
    then schema
    else if schema == {}
    then true
    else root.process(
      object,
      schema,
      root.genericTestCases
    ),

  process(object, schema, testcases):
    std.all([
      testcases[keyword](object, schema)
      for keyword in std.objectFields(testcases)
      if keyword in schema
    ]),

  types: {
    boolean(object, schema):
      trace(
        std.isBoolean(object),
        object,
        'not a boolean',
      ),

    'null'(object, schema):
      trace(
        std.type(object) == 'null',
        object,
        'not a null',
      ),

    string(object, schema)::
      if !std.isString(object)
      then trace(
        false,
        object,
        'not a string',
      )
      else root.process(
        object,
        schema,
        root.typeTestCases.string
      ),

    number(object, schema)::
      if !std.isNumber(object)
      then trace(
        false,
        object,
        'not a number',
      )
      else root.process(
        object,
        schema,
        root.typeTestCases.number
      ),

    integer(object, schema)::
      if !std.isNumber(object)
         && std.mod(object, 1) != 0
      then trace(
        false,
        object,
        'not an integer',
      )
      else root.process(
        object,
        schema,
        root.typeTestCases.number
      ),

    object(object, schema)::
      if !std.isObject(object)
      then
        trace(
          false,
          object,
          'not an object',
        )
      else root.process(
        object,
        schema,
        root.typeTestCases.object
      ),

    array(object, schema)::
      if !std.isArray(object)
      then trace(
        false,
        object,
        'not an array',
      )
      else root.process(
        object,
        schema,
        root.typeTestCases.array
      ),
  },

  notImplemented(key, schema):
    std.trace('JSON Schema attribute `%s` not implemented.' % key, true),

  genericTestCases: {
    enum(object, schema):
      trace(
        std.member(schema.enum, object),
        object,
        'invalid enum, value should be one of %s' % std.manifestJson(schema.enum),
      ),

    const(object, schema):
      trace(
        object == schema.const,
        object,
        'invalid const, value should be %s' % schema.const,
      ),

    not(object, schema):
      trace(
        !root.validate(object, schema.not),
        object,
        'invalid not, should not match %s' % schema.not,
      ),

    allOf(object, schema):
      std.all([
        root.validate(object, s)
        for s in schema.allOf
      ]),

    anyOf(object, schema):
      std.any([
        root.validate(object, s)
        for s in schema.anyOf
      ]),

    oneOf(object, schema):
      std.length([
        true
        for s in schema.oneOf
        if root.validate(object, s)
      ]) == 1,

    'if'(object, schema):
      // TODO: don't show trace message for `if` conditional
      if root.validate(
        object,
        std.mergePatch(
          schema + { 'if': true, 'then': true },
          schema['if']
        )
      )
      then
        if 'then' in schema
        then
          root.validate(
            object,
            std.mergePatch(
              schema + { 'if': true, 'then': true },
              schema['then']
            )
          )
        else true
      else
        if 'else' in schema
        then
          root.validate(
            object,
            std.mergePatch(
              schema + { 'if': true, 'then': true },
              schema['else']
            )
          )
        else true,

    type(object, schema):
      if std.isBoolean(schema.type)
      then trace(
        object != null,
        object,
        'invalid type, should not be null',
      )

      // TODO: don't show trace message for every failure in std.any
      else if std.isArray(schema.type)
      then std.any([
        root.types[t](object, schema)
        for t in schema.type
      ])

      else root.types[schema.type](object, schema),
  },

  typeTestCases: {
    string: {
      minLength(object, schema):
        trace(
          std.length(object) >= schema.minLength,
          object,
          'string too short, expected minLength %s' % schema.minLength,
        ),

      maxLength(object, schema):
        trace(
          std.length(object) <= schema.maxLength,
          object,
          'string too long, expected maxLength %s' % schema.maxLength,
        ),

      pattern(object, schema):
        root.notImplemented('pattern', schema),

      // vocabulary specific
      //format(object, schema):
      //  root.notImplemented('format', schema),
    },

    number: {
      multipleOf(object, schema):
        trace(
          std.mod(object, schema.multipleOf) == 0,
          object,
          'number not a multipleOf %s' % schema.multipleOf,
        ),

      minimum(object, schema):
        trace(
          object >= schema.minimum,
          object,
          'number too small, expected minimum %s' % schema.minimum,
        ),

      maximum(object, schema):
        trace(
          object <= schema.maximum,
          object,
          'number too big, expected maximum %s' % schema.maximum,
        ),

      exclusiveMinimum(object, schema):
        if std.isBoolean(schema.exclusiveMinimum)  // Draft 4 defines this as a boolean
        then
          if 'minimum' in schema
          then
            if schema.exclusiveMinimum
            then object > schema.minimum
            else object >= schema.minimum
          else true  // invalid schema doesn't mean invalid object
        else trace(
          object > schema.exclusiveMinimum,
          object,
          'number too small, expected exclusiveMinimum %s' % schema.exclusiveMinimum,
        ),


      exclusiveMaximum(object, schema):
        if std.isBoolean(schema.exclusiveMaximum)  // Draft 4 defines this as a boolean
        then
          if 'maximum' in schema
          then
            if schema.exclusiveMaximum
            then object > schema.maximum
            else object >= schema.maximum
          else true  // invalid schema doesn't mean invalid object
        else trace(
          object > schema.exclusiveMaximum,
          object,
          'number too small, expected exclusiveMaximum %s' % schema.exclusiveMaximum,
        ),
    },

    object: {
      patternProperties(object, schema):
        root.notImplemented('patternProperties', schema),
      dependentRequired(object, schema):
        root.notImplemented('dependentRequired', schema),
      unevaluatedProperties(object, schema):
        root.notImplemented('unevaluatedProperties', schema),
      additionalProperties(object, schema):
        root.notImplemented('additionalProperties', schema),

      properties(object, schema):
        std.all([
          root.validate(object[property], schema.properties[property])
          for property in std.objectFields(schema.properties)
          if property in object
        ]),

      required(object, schema):
        local result = std.all([
          std.member(std.objectFields(object), property)
          for property in schema.required
        ]);
        trace(
          result,
          object,
          'object missing one or more required fields %s' % std.manifestJson(schema.required),
        ),

      propertyNames(object, schema):
        std.all([
          root.typeTestCases.string(property, schema.propertyNames)
          for property in std.objectFields(schema)
        ]),

      minProperties(object, schema):
        trace(
          std.count(std.objectFields(object)) >= schema.minProperties,
          object,
          'object has too few properties, expected minProperties %s' % schema.minProperties,
        ),

      maxProperties(object, schema):
        trace(
          std.count(std.objectFields(object)) <= schema.maxProperties,
          object,
          'object has too many properties, expected maxProperties %s' % schema.maxProperties,
        ),

    },

    array: {
      minItems(object, schema):
        trace(
          std.length(object) >= schema.minItems,
          object,
          'array has too few items, expected minItems %s' % schema.minItems,
        ),

      maxItems(object, schema):
        trace(
          std.length(object) <= schema.maxItems,
          object,
          'array has too many items, expected maxItems %s' % schema.maxItems,
        ),

      uniqueItems(object, schema):
        local f = function(x) std.md5(std.manifestJson(x));
        if schema.uniqueItems
        then trace(
          std.set(object, f) == std.sort(object, f),
          object,
          'array items should be unique',
        )
        else true,

      prefixItems(object, schema):
        local result = (
          if std.length(schema.prefixItems) > 0
          then
            local lengthCheck =
              if 'items' in schema
                 && std.isBoolean(schema.items)
                 && !schema.items
              then std.length(object) == std.length(schema.prefixItems)
              else std.length(object) >= std.length(schema.prefixItems);

            if !lengthCheck
            then false
            else
              std.all([
                root.validate(object[i], schema.prefixItems[i])
                for i in std.range(0, std.length(schema.prefixItems) - 1)
              ])
          else true
        );
        trace(
          result,
          object,
          'array items do not match prefixItems',
        ),

      items(object, schema):
        local result = (
          if std.isBoolean(schema.items)
          then true  // only valid in the context of prefixItems
          else
            if std.length(object) == 0
            then true  // validated by prefixItems and min/maxLength
            else
              local count =
                if 'prefixItems' in schema
                then std.length(schema.prefixItems)
                else 0;
              std.all([
                root.validate(item, schema.items)
                for item in object[count:]
              ])
        );
        trace(
          result,
          object,
          'array one or more items do not match schema',
        ),

      contains(object, schema):
        local result = (
          local validated = [
            true
            for item in object
            if root.validate(item, schema.contains)
          ];
          std.any(validated)
          && std.all([
            if 'minContains' in schema
            then std.length(validated) >= schema.minContains
            else true,
            if 'maxContains' in schema
            then std.length(validated) <= schema.maxContains
            else true,
          ])
        );
        trace(
          result,
          object,
          'array does not contain required items %s' % schema.contains,
        ),

      unevaluatedItems(object, schema):
        root.notImplemented('unevaluatedItems', schema),
    },
  },
}
