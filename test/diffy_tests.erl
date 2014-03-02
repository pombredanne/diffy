%% @author Maas-Maarten Zeeman <mmzeeman@xs4all.nl>
%% @copyright 2014 Maas-Maarten Zeeman
%%
%% @doc Diffy, an erlang diff match and patch implementation 
%%
%% Copyright 2014 Maas-Maarten Zeeman
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%% Erlang diff-match-patch implementation

-module(diffy_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").


pretty_html_test() ->
    ?assertEqual([], diffy:pretty_html([])),
    ?assertEqual([<<"<span>>test</span>">>], diffy:pretty_html([{equal, <<"test">>}])),
    ?assertEqual([<<"<del style='background:#ffe6e6;'>foo</del>">>, 
        <<"<span>>test</span>">>], diffy:pretty_html([{delete, <<"foo">>}, {equal, <<"test">>}])),
    ?assertEqual([<<"<ins style='background:#e6ffe6;'>foo</ins>">>, 
        <<"<span>>test</span>">>], diffy:pretty_html([{insert, <<"foo">>}, {equal, <<"test">>}])),
    ok.

source_text_test() ->
    ?assertEqual(<<"fruit flies like a banana">>, 
        diffy:source_text([{equal,<<"fruit flies ">>}, {delete,<<"lik">>}, {equal,<<"e">>},
            {insert,<<"at">>}, {equal,<<" a banana">>}])),
    ok.

destination_text_test() ->
    ?assertEqual(<<"fruit flies eat a banana">>, 
        diffy:destination_text([{equal,<<"fruit flies ">>}, {delete,<<"lik">>}, {equal,<<"e">>},
            {insert,<<"at">>}, {equal,<<" a banana">>}])),
    ok.


levenshtein_test() ->
    ?assertEqual(0, diffy:levenshtein([])),
    ?assertEqual(5, diffy:levenshtein([{equal,<<"fruit flies ">>}, {delete,<<"lik">>}, 
        {equal,<<"e">>}, {insert,<<"at">>}, {equal,<<" a banana">>}])),

    % Levenshtein with trailing equality.
    ?assertEqual(4, diffy:levenshtein([{delete, <<"abc">>}, {insert, <<"1234">>}, {equal, <<"xyz">>}])),
    % Levenshtein with leading equality.
    ?assertEqual(4, diffy:levenshtein([{equal, <<"xyz">>}, {delete, <<"abc">>}, {insert, <<"1234">>}])),
    % Levenshtein with middle equality.
    ?assertEqual(7, diffy:levenshtein([{delete, <<"abc">>}, {equal, <<"xyz">>}, {insert, <<"1234">>}])),

    ok.

make_patch_test() ->
	%% No patches...
	?assertEqual([], diffy:make_patch([])),

	%% Source and destination text is the same.
	?assertEqual([], diffy:make_patch(<<>>, <<"abc">>)),

	%% Source and destination text is the same.
	?assertEqual([], diffy:make_patch(<<"abc">>, <<"abc">>)),

	ok.


cleanup_merge(Diffs) ->
    diffy:cleanup_merge(Diffs).
    
cleanup_merge_test() ->
    % no change..
    ?assertEqual([], cleanup_merge([])),

    % no change
    ?assertEqual([{equal, <<"a">>}, {delete, <<"b">>}, {insert, <<"c">>}], 
        cleanup_merge([{equal, <<"a">>}, {delete, <<"b">>}, {insert, <<"c">>}])),

    % Merge equalities
    ?assertEqual([{equal, <<"abc">>}], 
        cleanup_merge([{equal, <<"a">>}, {equal, <<"b">>}, {equal, <<"c">>}])),
    ?assertEqual([{delete, <<"abc">>}], 
        cleanup_merge([{delete, <<"a">>}, {delete, <<"b">>}, {delete, <<"c">>}])),
    ?assertEqual([{insert, <<"abc">>}], 
        cleanup_merge([{insert, <<"a">>}, {insert, <<"b">>}, {insert, <<"c">>}])),

    % Merge interweaves before equal operations
    ?assertEqual([{delete, <<"ac">>}, {insert, <<"bd">>}, {equal, <<"ef">>}], 
        cleanup_merge([{delete, <<"a">>}, {insert, <<"b">>}, {delete, <<"c">>}, {insert, <<"d">>}, 
            {equal, <<"e">>}, {equal, <<"f">>}])),

    % Prefix and suffix detection with equalities.
    ?assertEqual([{equal, <<"xa">>}, {delete, <<"d">>}, {insert, <<"b">>}, {equal, <<"cy">>}], 
        cleanup_merge([{equal, <<"x">>}, {delete, <<"a">>}, {insert, <<"abc">>}, {delete, <<"dc">>}, {equal, <<"y">>}])),

    % Slide left edit
    ?assertEqual([{insert, <<"ab">>}, {equal, <<"ac">>}],
        cleanup_merge([{equal, <<"a">>}, {insert, <<"ba">>}, {equal, <<"c">>}])),

    % Slide right edit
    ?assertEqual([{equal, <<"ca">>}, {insert, <<"ba">>}],
        cleanup_merge([{equal, <<"c">>}, {insert, <<"ab">>}, {equal, <<"a">>}])),

    % Slide edit left recursive.
    ?assertEqual([{delete, <<"abc">>}, {equal, <<"acx">>}],
        cleanup_merge([{equal, <<"a">>}, {delete, <<"b">>}, {equal, <<"c">>}, {delete, <<"ac">>}, {equal, <<"x">>}])),

    % Slide edit right recursive
    ?assertEqual([{equal, <<"xca">>}, {delete, <<"cba">>}],
        cleanup_merge([{equal, <<"x">>}, {delete, <<"ca">>}, {equal, <<"c">>}, {delete, <<"b">>}, {equal, <<"a">>}])),

    ok.

prop_cleanup_merge() ->
    ?FORALL(Diffs, diffy:diffs(),
        begin
            SourceText = diffy:source_text(Diffs),
            DestinationText = diffy:destination_text(Diffs),

            CleanDiffs = cleanup_merge(Diffs),

            SourceText == diffy:source_text(CleanDiffs) andalso
            DestinationText == diffy:destination_text(CleanDiffs)
        end).

cleanup_merge_prop_test() ->
    ?assertEqual(true, proper:quickcheck(prop_cleanup_merge(), [{numtests, 1000}, {to_file, user}])),
    ok.