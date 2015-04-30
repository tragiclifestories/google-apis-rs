<%namespace name="util" file="../../lib/util.mako"/>\
<%!
    import os

    from util import (put_and, supports_scopes, api_index, indent_by, enclose_in, put_and)
    from cli import (mangle_subcommand, new_method_context, PARAM_FLAG, STRUCT_FLAG, UPLOAD_FLAG, OUTPUT_FLAG, VALUE_ARG,
                     CONFIG_DIR, SCOPE_FLAG, is_request_value_property, FIELD_SEP, docopt_mode, FILE_ARG, MIME_ARG, OUT_ARG, 
                     CONFIG_DIR_FLAG, KEY_VALUE_ARG, to_docopt_arg, DEBUG_FLAG, DEBUG_AUTH_FLAG, MODE_ARG, SCOPE_ARG, 
                     CONFIG_DIR_ARG, FILE_FLAG, MIME_FLAG)

    def rust_boolean(v):
        return v and 'true' or 'false'

    def rust_optional(v):
        if v is None:
            return 'None'
        if isinstance(v, bool):
            v = v and 'true' or 'false'
        elif isinstance(v, basestring):
            v = '"%s"' % v.replace('"', r'\"')
        elif isinstance(v, list):
            v = 'vec![%s]' % ','.join('UploadProtocol::%s' % p.capitalize() for p in v)
        return 'Some(%s)' % v
%>\
<%def name="grammar(c)">\
${util.program_name()} [options]
% for resource in sorted(c.rta_map.keys()):
        ${mangle_subcommand(resource)}
    % for method in sorted(c.rta_map[resource]):
<%
    mc = new_method_context(resource, method, c)

    args = list()
    for p in mc.required_props:
        if is_request_value_property(mc, p):
            continue
        args.append(to_docopt_arg(p))
    # end for each required property

    if mc.request_value:
        args.append('(-%s %s)...' % (STRUCT_FLAG, '<%s>' % KEY_VALUE_ARG))
    # end request_value

    if mc.media_params:
        upload_protocols = [mp.protocol for mp in mc.media_params]
        mode = docopt_mode(upload_protocols)
        args.append('(-%s %s -%s <%s> [-%s <%s>])' % (UPLOAD_FLAG, mode, FILE_FLAG, FILE_ARG, MIME_FLAG, MIME_ARG))
    # end upload handling

    if mc.optional_props or parameters is not UNDEFINED:
        args.append('[-%s %s]...' % (PARAM_FLAG, '<%s>' % VALUE_ARG))
    # end paramters
    
    if mc.response_schema or mc.m.get('supportsMediaDownload', False):
        args.append('[-%s <%s>]' % (OUTPUT_FLAG, OUT_ARG))
    # handle output
%>\
                ${mangle_subcommand(method)} ${' '.join(args)}
    % endfor # each method
% endfor # end for each resource
  ${util.program_name()} --help

All documentation details can be found at
${cargo.doc_base_url + '/' + os.path.dirname(api_index(cargo.doc_base_url, name, version, make, check_exists=False))}

Configuration:
% if supports_scopes(auth):
  [--${SCOPE_FLAG} <${SCOPE_ARG}>]...
            Specify the authentication a method should be executed in. Each scope 
            requires the user to grant this application permission to use it. 
            If unset, it defaults to the shortest scope url for a particular method.
% endif scopes
  --${CONFIG_DIR_FLAG} <${CONFIG_DIR_ARG}>
            A directory into which we will store our persistent data. Defaults to 
            a user-writable directory that we will create during the first invocation.
            [default: ${CONFIG_DIR}]
  --${DEBUG_FLAG}
            Output all server communication to standard error. `tx` and `rx` are placed 
            into the same stream.
  --${DEBUG_AUTH_FLAG}
            Output all communication related to authentication to standard error. `tx` 
            and `rx` are placed into the same stream.
</%def>



<%def name="new(c)" buffered="True">\
<%
    url_info = "All documentation details can be found at " + \
                cargo.doc_base_url + '/' + os.path.dirname(api_index(cargo.doc_base_url, name, version, make, check_exists=False))

    # list of tuples
    # (0) = long name
    # (1) = description
    # (2) = argument name, no argument if no argument
    # (3) = multiple
    global_args = list()
    if supports_scopes(auth):
        global_args.append((
            SCOPE_FLAG,
            "Specify the authentication a method should be executed in. Each scope "
            "requires the user to grant this application permission to use it."
            "If unset, it defaults to the shortest scope url for a particular method.",
            SCOPE_ARG,
            True
        ))
    # end add scope arg
    global_args.append((
        CONFIG_DIR_FLAG,
        "A directory into which we will store our persistent data. Defaults to "
        "a user-writable directory that we will create during the first invocation."
        "[default: %s" % CONFIG_DIR,
        CONFIG_DIR_ARG,
        False,
    ))

    global_args.append((
        DEBUG_FLAG,  
        "Output all server communication to standard error. `tx` and `rx` are placed "
        "into the same stream.",
        None,
        False,
    ))

    global_args.append((
        DEBUG_AUTH_FLAG,
        "Output all communication related to authentication to standard error. `tx` "
        "and `rx` are placed into the same stream.",
        None,
        False,
    ))
%>\
let arg_data = [
% for resource in sorted(c.rta_map.keys()):
<% 
    methods = sorted(c.rta_map[resource])
%>\
<%block filter="indent_by(4)">\
("${mangle_subcommand(resource)}", "supported subcommands: ${put_and(["'%s'" % mangle_subcommand(m) for m in methods])}", vec![
    % for method in methods:
<%
    mc = new_method_context(resource, method, c)

    # A list of tuples
    # (0) = short flag, like -c
    # (1) = param description or None
    # (2) = argument name, or None if there is no argument
    # (3) = is required (bool)
    # (4) = allow multi-use
    args = list()
    for p in mc.required_props:
        if is_request_value_property(mc, p):
            continue
        args.append((
            None,
            p.get('description'),
            mangle_subcommand(p.name),
            True,
            False,
            None,
        ))
    # end for each required property

    if mc.request_value:
        args.append((
                STRUCT_FLAG,
                "Set various fields of the request structure",
                KEY_VALUE_ARG,
                True,
                True,
                None
            ))
    # end request_value

    if mc.media_params:
        upload_protocols = [mp.protocol for mp in mc.media_params]
        args.append((
                UPLOAD_FLAG,
                "Specify which file to upload",
                MODE_ARG,
                True,
                False,
                upload_protocols
            ))
    # end upload handling

    if mc.optional_props or parameters is not UNDEFINED:
        args.append((
                PARAM_FLAG,
                "Set various fields of the request structure",
                VALUE_ARG,
                False,
                True,
                None
            ))
    # end paramters
    
    if mc.response_schema or mc.m.get('supportsMediaDownload', False):
        args.append((
                OUTPUT_FLAG,
                "Specify the file into which to write the programs output",
                OUT_ARG,
                False,
                False,
                None
            ))
    # handle output
%>\
    ("${mangle_subcommand(method)}",  ${rust_optional(mc.m.get('description'))}, 
          vec![
            % for flag, desc, arg_name, required, multi, upload_protocols in args:
            (${rust_optional(arg_name)},
             ${rust_optional(flag)},
             ${rust_optional(desc)},
             ${rust_optional(required)},
             ${rust_optional(multi)},
             % if not mc.media_params:
             ## Make sure the type is set, even though we don't have any protocol information
             % if loop.first:
             None::${'<Vec<UploadProtocol>>'}\
             % else:
             None\
             % endif
             % else:
             ${rust_optional(upload_protocols)}\
             % endif
),
            % if not loop.last:

            % endif
            % endfor
          ]),
    % endfor # each method
    ]),
</%block>
% endfor # end for each resource
];

let mut app = App::new("${util.program_name()}")
<%block filter="indent_by(7)">\
.author("${', '.join(cargo.authors)}")
.version("${util.crate_version()}")
% if description is not UNDEFINED:
.about("${description}")
% endif
.after_help("${url_info}")
% for flag, desc, arg_name, multiple in global_args:
.arg(Arg::with_name("${arg_name or flag}")
        .long("${flag}")
        .help("${desc}")
        .multiple(${rust_boolean(multiple)})
        .takes_value(${rust_boolean(arg_name)}))\
% if loop.last:
;
% else:

% endif
% endfor

for &(main_command_name, ref about, ref subcommands) in arg_data.iter() {
    let mut mcmd = SubCommand::new(main_command_name).about(about);

    for &(sub_command_name, ref desc, ref args) in subcommands {
        let mut scmd = SubCommand::new(sub_command_name);
        if let &Some(desc) = desc {
            scmd = scmd.about(desc);
        }

        for &(ref arg_name, ref flag, ref desc, ref required, ref multi, ref protocols) in args {
            let mut arg = Arg::with_name(match (arg_name, flag) {
                                                (&Some(an), _       ) => an,
                                                (_        , &Some(f)) => f,
                                                 _                    => unreachable!(),
                                         });
            if let &Some(short_flag) = flag {
                arg = arg.short(short_flag);
            }
            if let &Some(desc) = desc {
                arg = arg.help(desc);
            }
            if arg_name.is_some() && flag.is_some() {
                arg = arg.takes_value(true);
            }
            if let &Some(required) = required {
                arg = arg.required(required);
            }
            if let &Some(multi) = multi {
                arg = arg.multiple(multi);
            }
            if let &Some(ref protocols) = protocols {
                arg = arg.possible_values(protocols);
                arg = arg.requires("${FILE_ARG}");

                scmd = scmd.arg(Arg::with_name("${FILE_ARG}")
                                    .short("${FILE_FLAG}")
                                    .required(true)
                                    .requires("${MODE_ARG}")
                                    .help("The file to upload")
                                    .takes_value(true));
                scmd = scmd.arg(Arg::with_name("${MIME_ARG}")
                                    .short("${MIME_FLAG}")
                                    .requires("${MODE_ARG}")
                                    .requires("${FILE_ARG}")
                                    .required(false)
                                    .help("The file's mime time, like 'application/octet-stream'")
                                    .takes_value(true));
            }
            scmd = scmd.arg(arg);
        }
        mcmd = mcmd.subcommand(scmd);
    }
    app = app.subcommand(mcmd);
}
</%block>
</%def>