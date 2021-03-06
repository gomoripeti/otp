%%----------------------------------------------------------------------
%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2000-2011. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%
%%
%% 
%%----------------------------------------------------------------------
%% File        : CosPropertyService_PropertySetFactory_impl.erl
%% Description : 
%%
%%----------------------------------------------------------------------
-module('CosPropertyService_PropertySetFactory_impl').

%%----------------------------------------------------------------------
%% Include files
%%----------------------------------------------------------------------
-include_lib("orber/include/corba.hrl").
-include_lib("orber/src/orber_iiop.hrl").
-include("CosPropertyService.hrl").
-include("cosProperty.hrl").

%%----------------------------------------------------------------------
%% External exports
%%----------------------------------------------------------------------
-export([init/1,
	 terminate/2,
	 code_change/3]).

-export([create_propertyset/2, 
	 create_constrained_propertyset/4, 
	 create_initial_propertyset/3]).


%%----------------------------------------------------------------------
%% Internal exports
%%----------------------------------------------------------------------
-export([]).

%%----------------------------------------------------------------------
%% Records
%%----------------------------------------------------------------------
-record(state, {}).

%%----------------------------------------------------------------------
%% Macros
%%----------------------------------------------------------------------
-define(checkTCfun,   fun(TC) -> orber_tc:check_tc(TC) end).

%%======================================================================
%% External functions
%%======================================================================
%%----------------------------------------------------------------------
%% Function   : init/1
%% Returns    : {ok, State}          |
%%              {ok, State, Timeout} |
%%              ignore               |
%%              {stop, Reason}
%% Description: Initiates the server
%%----------------------------------------------------------------------
init([]) ->
    {ok, #state{}}.

%%----------------------------------------------------------------------
%% Function   : terminate/2
%% Returns    : any (ignored by gen_server)
%% Description: Shutdown the server
%%----------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%----------------------------------------------------------------------
%% Function   : code_change/3
%% Returns    : {ok, NewState}
%% Description: Convert process state when code is changed
%%----------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%----------------------------------------------------------------------
%% Function   : create_propertyset
%% Arguments  : 
%% Returns    : CosPropertyService::PropertySet reference.
%% Description: 
%%----------------------------------------------------------------------
create_propertyset(_OE_This, State) ->
    {reply, 
     'CosPropertyService_PropertySetDef':
     oe_create({normal, [], [], [], ?PropertySet}, [{pseudo, true}]),
     State}.

%%----------------------------------------------------------------------
%% Function   : create_constrained_propertyset
%% Arguments  : PropTypes  - list of property types.
%%              Properties - list of properties.
%% Returns    : CosPropertyService::PropertySet |
%%              {'EXCEPTION', CosPropertyService::ConstraintNotSupported}
%% Description: 
%%----------------------------------------------------------------------
create_constrained_propertyset(_OE_This, State, PropTypes, Properties) ->
    case lists:all(?checkTCfun, PropTypes) of
	true ->
	    crosscheckTC(Properties, PropTypes),
	    {reply, 
	     'CosPropertyService_PropertySetDef':
	     oe_create({normal, PropTypes, Properties, [], ?PropertySet}, 
		       [{pseudo, true}]),
	     State};
	false ->
	    corba:raise(#'CosPropertyService_ConstraintNotSupported'{})
    end.

crosscheckTC([], _) ->
    ok;
crosscheckTC([#'CosPropertyService_Property'
			 {property_name = Name,
			  property_value = Value}|T], TCs) ->
    case lists:member(any:get_typecode(Value), TCs) of
	true when Name =/= "" ->
	   crosscheckTC(T, TCs); 
	_ ->
	    corba:raise(#'CosPropertyService_ConstraintNotSupported'{})
    end.

%%----------------------------------------------------------------------
%% Function   : create_initial_propertyset
%% Arguments  : Properties - list of properties.
%% Returns    : CosPropertyService::PropertySetDef |
%%              {'EXCEPTION', CosPropertyService::MultipleExceptions}
%% Description: 
%%----------------------------------------------------------------------
create_initial_propertyset(_OE_This, State, Properties) ->
    InitProps = evaluate_propertyset(Properties),
    {reply, 
     'CosPropertyService_PropertySetDef':
	oe_create({normal, [], [], InitProps, ?PropertySet}, [{pseudo, true}]),
     State}.

%%======================================================================
%% Internal functions
%%======================================================================
evaluate_propertyset(Sets) ->
    case evaluate_propertyset(Sets, [], []) of
	{ok, NewProperties} ->
	    NewProperties;
	{error, Exc} ->
	    corba:raise(#'CosPropertyService_MultipleExceptions'{exceptions = Exc})
    end.

evaluate_propertyset([], NewProperties, []) ->
    %% No exceptions found.
    {ok, NewProperties};
evaluate_propertyset([], _, Exc) ->
    {error, Exc};
evaluate_propertyset([#'CosPropertyService_Property'
		      {property_name = Name,
		       property_value = Value}|T], X, Exc) ->
    case orber_tc:check_tc(any:get_typecode(Value)) of
	true ->
	    evaluate_propertyset(T, [{Name, Value, normal}|X], Exc);
	false ->
	    evaluate_propertyset(T, X, [#'CosPropertyService_PropertyException'
					{reason = unsupported_type_code,
					 failing_property_name = Name}|Exc])
    end.

%%======================================================================
%% END OF MODULE
%%======================================================================
