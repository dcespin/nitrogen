% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2009 Rusty Klophaus
% See MIT-LICENSE for licensing information.

-module (element_template).
-include ("wf.inc").
-compile(export_all).

% TODO - Revisit parsing in the to_module_callback. This
% will currently fail if we encounter a string like:
% "String with ) will fail" 
% or 
% "String with ]]] will fail"


reflect() -> record_info(fields, template).

render_element(_HtmlID, Record) ->
	% % Prevent loops.
	% case wf:state(template_was_called) of
	% 	true -> throw("Calling a template from a template.");
	% 	_ -> ignore
	% end,
	% wf:state(template_was_called, true),
	
	% Parse the template file...
	File = wf:to_list(Record#template.file),
	Template = parse_template(File),
	
	% IN PROGRESS - Caching
	% Key = {template, File},
	% Template = wf_cache:cache(Key, fun() -> parse_template(File) end, [{ttl, 5}]),
	
	% Evaluate the template.
	Body = eval(Template, Record),
	Body.


parse_template(File) ->
	% TODO - Templateroot
	% File1 = filename:join(nitrogen:get_templateroot(), File),
	File1 = File,
	case file:read_file(File1) of
		{ok, B} -> parse_template1(B);
		_ -> 
			?LOG("Error reading file: ~s~n", [File1]),
			wf:f("File not found: ~s.", [File1])
	end.

parse_template1(B) ->
	F = fun(Tag) -> 
		try 
			Tag1 = wf:to_list(Tag),
			to_module_callback(Tag1) 
		catch _ : _ ->
			?LOG("Invalid template tag: ~s~n", [Tag])
		end
	end,
	parse(B, F).
	

%%% PARSE %%%
	
%% parse/2 - Given a binary and a callback, look through the binary
%% for strings of the form [[[module]]] or [[[module:function(args)]]]
parse(B, Callback) -> parse(B, Callback, []).
parse(<<>>, _Callback, Acc) -> [lists:reverse(Acc)];
parse(<<"[[[", Rest/binary>>, Callback, Acc) -> 
	{ Token, Rest1 } = get_token(Rest, <<>>),
	[lists:reverse(Acc), Callback(Token)|parse(Rest1, Callback, [])];
parse(<<C, Rest/binary>>, Callback, Acc) -> parse(Rest, Callback, [C|Acc]).
	
get_token(<<"]]]", Rest/binary>>, Acc) -> { Acc, Rest };
get_token(<<H, Rest/binary>>, Acc) -> get_token(Rest, <<Acc/binary, H>>).

to_module_callback("script") -> script;
to_module_callback(Tag) ->
	% Get the module...
	{ModuleString, Rest1} = peel(Tag, $:),
	Module = wf:to_atom(ModuleString),
	
	% Get the function...
	{FunctionString, Rest2} = peel(Rest1, $(),
	Function = wf:to_atom(FunctionString),
	
	{ArgString, Rest3} = peel(Rest2, $)),
	
	case Rest3 of
		[] -> [{Module, Function, ArgString}];
		_ ->  [{Module, Function, ArgString}|to_module_callback(tl(Rest3))]
	end.

peel(S, Delim) -> peel(S, Delim, []).
peel([], _Delim, Acc) -> {lists:reverse(Acc), []};
peel([Delim|T], Delim, Acc) -> {lists:reverse(Acc), T};
peel([H|T], Delim, Acc) -> peel(T, Delim, [H|Acc]).

to_term(X, Bindings) ->
	S = wf:to_list(X),
	{ok, Tokens, 1} = erl_scan:string(S),
	{ok, Exprs} = erl_parse:parse_exprs(Tokens),
	{value, Value, _} = erl_eval:exprs(Exprs, Bindings),
	Value.



%%% EVALUATE %%%

eval([], _) -> [];
eval([script|T], Record) -> [script|eval(T, Record)];
eval([H|T], Record) when ?IS_STRING(H) -> [H|eval(T, Record)];
eval([H|T], Record) -> [replace_callbacks(H, Record)|eval(T, Record)].

% Turn callbacks into a reference to #function_el {}.
replace_callbacks(CallbackTuples, Record) ->
	Bindings = Record#template.bindings,
	Functions = [convert_callback_tuple_to_function(M, F, ArgString, Bindings) || {M, F, ArgString} <- CallbackTuples],
	#function_el { function=Functions }.
	
convert_callback_tuple_to_function(Module, Function, ArgString, Bindings) ->
	% De-reference to page module...
	Module1 = case Module of 
		page -> wf_context:page_module();
		_ -> Module
	end,
	
	_F = fun() ->
		% Convert args to term...
		Args = to_term("[" ++ ArgString ++ "].", Bindings),
		
		% If the function in exported, then call it. 
		% Otherwise return undefined...
		{module, Module1} = code:ensure_loaded(Module1),
		case erlang:function_exported(Module1, Function, length(Args)) of
			true -> _Elements = erlang:apply(Module1, Function, Args);
			false -> undefined
		end
	end.