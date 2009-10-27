% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2009 Rusty Klophaus
% See MIT-LICENSE for licensing information.

-module (wf_render_elements).
-include ("wf.inc").
-export ([
	render_elements/1,
	temp_id/0,
	to_html_id/1
]).

% render_elements(Elements) - {ok, Html}
% Render elements and return the HTML that was produced.
% Puts any new actions into the current context.
render_elements(Elements) ->
	{ok, _HtmlAcc} = render_elements(Elements, []).

% render_elements(Elements, HtmlAcc) -> {ok, Html}.
render_elements(S, HtmlAcc) when S == undefined orelse S == []  ->
	{ok, HtmlAcc};
	
render_elements(S, HtmlAcc) when is_binary(S) orelse ?IS_STRING(S) ->
	{ok, [S|HtmlAcc]};

render_elements(Elements, HtmlAcc) when is_list(Elements) ->
	F = fun(X, {ok, HAcc}) ->
		render_elements(X, HAcc)
	end,
	{ok, Html} = lists:foldl(F, {ok, []}, Elements),
	HtmlAcc1 = [lists:reverse(Html)|HtmlAcc],
	{ok, HtmlAcc1};
	
render_elements(Element, HtmlAcc) when is_tuple(Element) ->
	{ok, Html} = render_element(Element),
	HtmlAcc1 = [Html|HtmlAcc],
	{ok, HtmlAcc1};
	
render_elements(script, HtmlAcc) ->
	HtmlAcc1 = [script|HtmlAcc],
	{ok, HtmlAcc1};
	
render_elements(Unknown, _HtmlAcc) ->
	throw({unanticipated_case_in_render_elements, Unknown}).
	
% This is a Nitrogen element, so render it.
render_element(Element) when is_tuple(Element) ->
	% Get the element's backing module...
	Base = wf_utils:get_elementbase(Element),
	Module = Base#elementbase.module, 
	
	% Verify that this is an element...
	case Base#elementbase.is_element == is_element of
		true -> ok;
		false -> throw({not_an_element, Element})
	end,

	% Set the element ID if it is not already set...
	ID = case Base#elementbase.id of
		undefined -> wf:temp_id();
		Other -> wf:to_list(Other)
	end,
	
	NewPath = [wf:to_list(ID)|wf_context:current_path()],
	HtmlID = to_html_id(NewPath),
	
	% Update the base element with the new id...
	Base1 = Base#elementbase {id = ID},
	Element1 = wf_utils:replace_with_base(Base1, Element),
		
	% Push the new path into our list of dom_paths...
	wf_context:add_dom_path(NewPath),
	
	case {Base1#elementbase.show_if, is_temp_element(ID)} of
		{true, true} -> 			
			% This is a temp element. Don't update the current path, it should use the parent path.
			% Wire the actions, render the element...
			wf:wire(ID, Base1#elementbase.actions),
		 	{ok, _Html} = call_element_render(Module, HtmlID, Element1);

		{true, false} -> 
			% This is a named element. Update the current path.
			OldPath = wf_context:current_path(),
			wf_context:current_path(NewPath),
	
			% Wire the actions, render the element...
			wf:wire(me, Base1#elementbase.actions),
			{ok, Html} = call_element_render(Module, HtmlID, Element1),
					
			% Restore the old path...
			wf_context:current_path(OldPath),
			{ok, Html};
			
		{_, _} -> 
			{ok, []}
	end.
	
% call_element_render(Module, HtmlID, Element) -> {ok, Html}.
% Calls the render_element/3 function of an element to turn an element record into
% HTML.
call_element_render(Module, HtmlID, Element) ->
	{module, Module} = code:ensure_loaded(Module),
	NewElements = Module:render_element(HtmlID, Element),
	{ok, _Html} = render_elements(NewElements, []).


to_html_id(P) ->
	P1 = lists:reverse(P),
	string:join(P1, "__").
	
temp_id() ->
	{_, _, C} = now(), 
	"temp" ++ integer_to_list(C).


is_temp_element(undefined) -> true;
is_temp_element([P]) -> is_temp_element(P);
is_temp_element(P) -> 
	Name = wf:to_list(P),
	length(Name) > 4 andalso
	lists:nth(1, Name) == $t andalso
	lists:nth(2, Name) == $e andalso
	lists:nth(3, Name) == $m andalso
	lists:nth(4, Name) == $p.