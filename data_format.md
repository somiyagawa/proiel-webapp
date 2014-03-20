% The PROIEL web application data format
% Marius L. Jøhndal
% 22 April 2013

NOTE: This document is still *very* incomplete

## The core data fields

  Required = never NULL
  Optional = may be NULL
  Invalid = always NULL

  Any token
    id                           Required
    sentence_id                  Required
    token_number                 Required
    citation_part                Optional
    information_status_tag       Optional
    antecedent_id                Optional
    contrast_group               Optional
    token_alignment_id           Optional
    automatic_token_alignment    Optional
    dependency_alignment_id      Optional
    source_morphology_tag        Optional   (deprecated)
    source_lemma                 Optional   (deprecated)
    created_at                   Optional
    updated_at                   Optional

    (sentence_id, token_number) must be unique

  If not empty token
    form                         Required
    empty_token_sort             Invalid
    presentation_before          Optional
    presentation_after           Optional
    foreign_ids                  Optional

  If empty token (TODO: empty token must be attached somehow)
    form                         Invalid
    empty_token_sort             Required
    presentation_before          Invalid
    presentation_after           Invalid
    foreign_ids                  Invalid

  If not belongs to annotated sentence
    lemma_id                     Optional
    morphology_tag               Optional
    head_id                      Optional
    relation_tag                 Optional

  If belongs to annotated sentence
    lemma_id                     Required
    morphology_tag               Required
    head_id                      Optional   (1)
    relation_tag                 Required

    Only one token may have head_id == NULL

    (1) optional because the root of a dependency structure has head_id == NULL)

## Presentation text

_Presentation text_ is textual material that should be presented when a token,
sentence, source division or source is rendered but should remain unavailable
for annotation. Typical examples include punctuation, verse numbering and
section headings.

Presentation text is stored in the columns `presentation_before` and
`presentation_after` in the tables `tokens`, `sentences` and `source_divisions`.

The columns are intended for different purposes. The columns in the
`source_divisions` table can contain any amount of text. They are therefore
suitable for introductory material like prologues or chapter headings.

The columns in the `sentences` and `tokens` tables are intended for short
strings that are exempted for annotation. These columns are therefore restricted
to strings of a certain length (see the schema for exact value).

The `sentences` columns are intended for text that unambiguously indicates a
fixed break between sentences. An example would be stage directions in drama.

The `tokens` columns, on the other hand, should contain presentation text that
intervenes in the running text. This is typically punctuation and inter-word
spacing (including line breaks in poetry or drama).

Because of their different purposes, the columns have different semantics with
respect to merging of sentences. Two sentences can be merged when there is
presentation text intervening between them but only when this is represented in
the relevant `tokens` columns. If there is material in any of the `sentences`
columns, it is interpreted as a fixed sentence boundary, which prevents merging
of the two sentences.

Since sentences from different source divisions cannot be merged for independent
reasons, presentation text in the `source_divisions` table plays no role in
merging sentences.

### Representing whitespace

Whitespace in presentation text is not significant. To represent whitespace in
poetry and drama, the following Unicode should be used:

  1. For a line break, use `U+2028` (LINE SEPARATOR)
  2. For a paragraph break, use `U+2029` (PARAGRAPH SEPARATOR)
  3. For an indented line (in poetry, after a line break), use TODO
  4. For a caesura (in poetry, within a line), use TODO

### Rendering

The principles for rendering presentation text (as HTML) are the same for all
the relevant columns:

  1. Concatenate all relevant presentation columns, `tokens.form` and any other
     metadata (e.g. citations with HTML markup).
  2. Map `U+2028` (LINE SEPARATOR) to the HTML tag `<br>` and `U+2029`
     (PARAGRAPH SEPARATOR) to the HTML tag `<p>`.
  3. Replace any sequence of whitespace with a single space character (ASCII
     13).
  4. Remove any whitespace from the beginning and end of the string.

## Language tags

Columns named `language_tag` contain an ISO-639-3 (three letter) language tag.
Valid tags are all tags defined in the most recent version of the ISO-639-3
standard. See SIL's [ISO-639-3 code
table](http://www.sil.org/iso639-3/codes.asp) for a list of valid codes.

## Alignment data

For all alignments the directionality of the alignment relations is from the
secondary source, i.e. the assumed translation, to the primary source, i.e. the
assumed original.

### Sentence alignment

Column                                         Description
------                                         -----------
`source_divisions.aligned_source_division_id`  The source division this source division should be aligned to. This should be set on secondary sources only. The relation is used to determine the scope of automatic sentence alignment.
`sentences.unalignable`                        If true, the sentence is, for the purposes of sentence alignment, not to be considered as an independent unit, but rather as part of the previous sentence in the linear ordering of sentences. This is, in other words, an indication that the sentence has been 'black- listed' from sentence alignment.
`sentences.automatic_alignment`                If true, the sentence alignment indicated by `sentences.sentence_alignment_id` has been generated automatically and is therefore more likely to be wrong and thus more likely to be a candidate for deletion should alignment need to be adjusted at a later stage. The flag is set when automatic sentence alignment is committed and unset when it is uncommitted.
`sentences.sentence_alignment_id`              The sentence this sentence is aligned with. This sentence alignment has been provided manually unless `sentences.automatic_alignment` is set.

### Token alignment

Column                               Description
------                               -----------
`tokens.token_alignment_id`          The token this token is aligned with for the purposes of token alignment. This token alignment has been provided manually unless `tokens.automatic_token_alignment` is set.
`tokens.automatic_token_alignment`   If true, the token alignment indicated by `tokens.token_alignment_id` has been generated automatically.

### Dependency alignment

Column                                        Description
------                                        -----------
`tokens.dependency_alignment_id`              The token that is the head of the dependency subgraph this token is aligned with for the purposes of dependency alignment.
`dependency_alignment_terminations.token_id`  The token whose dependency subgraph has a termination, i.e. which is not part of its heads dependency subgraph alignment.
`dependency_alignment_terminations.source_id` The target source for the termination in `dependency_alignment_terminations.token_id`. This is required since terminations can occur in both primary and secondary sources, and only for those from secondary sources can the relationship between the alignments be inferred automatically.

## References to external data

Column                                        Description
------                                        -----------
`sentences.foreign_ids`                       A comma separated string of key-value pairs on the format key=value that can used to store identifiers or meta-data associated with the row. This is intended to be used typically as semi-permanent holding space for data that does not yet fit into the data model, but is likely to be useful for future extensions. Example: `source_segment_id=T567,witness=CA`
`tokens.foreign_ids`                          See `sentences.foreign_ids`
`lemmata.foreign_ids`                         See `sentences.foreign_ids`

## Part of speech and morphology

_Part of speech_ consists of the `morphtag` fields `major` and
`minor`. The remaining morphtag fields form part of the _morphology_.
As for the `inflection` field there are arguments in favour of
treating this both as part of the part of speech and as part of the
morphology. In keeping with the philosophy that each unique (_lemma_,
_part of speech_) pair should be a unique lemma, it may make sense to
assign inflecting and non-inflecting forms to different lemmata as
well when these behave differently, but there are also legitimate
cases where forms of a lemma for no apparent reason remain uninflected
in certain situations. By treating the `inflection` field as part of
part of speech, we would force unique lemmata for each combination,
but by treating it as part of the morphology, both options remain
open.

# Maintenance tasks

A list of all the maintenance tasks can be obtained by running the command `rake -T proiel`:

    $ rake -T proiel
    rake proiel:dictionary:import             # Import a PROIEL dictionary.
    rake proiel:history:prune:attribute       # Prune an attribute from history.
    rake proiel:morphology:force_manual_tags  # Force manual morphological rules.
    ...

A number of these tasks are explained in more detail below.

`proiel:text:export`
--------------------

This task exports texts and annotation to a number of different formats.

The source to export is identified using the variable `ID`, which should
correspond to the numeric ID of the source in the database. If no `ID` is given,
all sources will be exported.

The variable `FORMAT` is used to select the export format. By default, the
PROIEL XML format is used. Other alternatives are `conll`, `tigerxml` and
`tiger2`.

`MODE` is by default `all`, which will export all available data. Alternatively, the
setting `reviewed` will only export sentences that have been reviewed.

The variable `DIRECTORY` overrides the export directory. By default, the
path given by `config.export_file_path` is used. The file name is generated from
the `citation-part` column of the source or the `id` column if no
`citation_part` has been set.

PROIEL XML is automatically validated. The schema file used for validation is
found in the path given by `config.schema_file_path`.

If you wish to validate a PROIEL XML file manually, you can use the tool
`xmllint`, e.g.

    xmllint --nonet --noout --path public/exports/ --schema public/exports/text.xsd mytext.xml

`proiel:morphology:reassign`
----------------------------

This task is used to change all occurrences of a particular value of a
morphological field to another value in the `tokens` table, i.e. to
change the `source_morphology` field. For example

    $ rake proiel:morphology:reassign FIELD=voice FROM=o TO=p
    ...

will replace the value `p` with `o` in the `voice` field. No further
restrictions on the operation can be given, so the task is only useful
for keeping tag set and database synchronised.

`proiel:morphology:force_manual_tags`
-------------------------------------

This task will apply the morphology set out in manually crafted morpholgical rules
to all tokens that match the criteria in the rules for given sources. This can be
used to overwrite bad annotations once the manually crafted morphological rules are
deemed to be entirely correct.

    $ rake proiel:morphology:force_manual_tags SOURCES=perseus-vulgate-synth
     INFO manual-tagger: Working on source perseus-vulgate-synth...
    ERROR manual-tagger: Token 251733 (sentence 12871) 'in': Tagged with closed class morphology but not found in definition.
    ERROR manual-tagger: Token 251782 (sentence 12878) 'quia': Tagged with closed class morphology but not found in definition.

`proiel:history:prune:attribute`
--------------------------------

This task is used to completely remove all entries that refer to particular
attribute from the history. This is occasionally useful when changing the database
schema when columns are removed and the data lost by the change is of no future value.

Example:

    $ rake proiel:history:prune:attribute MODEL=Token ATTRIBUTE=morphtag_source
    Removing attribute Token.morphtag_source from audit 17695
    Removing attribute Token.morphtag_source from audit 17696
    Removing attribute Token.morphtag_source from audit 17698
    Removing attribute Token.morphtag_source from audit 17701
    Removing attribute Token.morphtag_source from audit 17702
    Removing attribute Token.morphtag_source from audit 17703
    ...

`proiel:validate`
-----------------

This task validates the entire database, first using model validations for each, then
using secondary constraints that have not been implemented in the models. Some of these
are designed to be auto-correcting, e.g. orphaned lemmata are cleaned up by this task.

The task is intended to be run whenever the annotation scheme is modified to ensure that
all annotation remains valid.

`proiel:notes:import`
---------------------

This task can be used for mass-import of notes. The data file should
be provided in the argument `FILE` and should be a comma-separated
file on the following format:

    User,2,Sentence,12345,"a long comment here"

`proiel:dependency_alignments:import`
-------------------------------------

This task can be used for mass-import of dependency alignment. The data file should be
a comma-separated file on the following format:

    ALIGN,12345,67890
    TERMINATE,12346,2

This will align the dependency subgraph for token 67890 (in the secondary source)
with the dependency subgraph for token 12345 (in the primary source). It will then
terminate the dependency subgraph for token 12346 (in the primary source) with
respect to the secondary source with ID 2.

`proiel:semantic_tags:import` and `proiel:semantic_tags:export`
---------------------------------------------------------------

These tasks can be used for mass-import and -export of semantic tags. The data file is
expected to be a comma-separated file with the following fields:

  * Taggable type (string, either `Token` or `Lemma`)
  * Taggable ID (integer)
  * Attribute tag (string)
  * Attribute value tag (string)

All attributes and attribute values must already have been defined; so must any
referred token or lemmma.

Example:

    $ rake proiel:semantic_tags:export FILE=tags.csv
    $ cat tags.csv
    Token,266690,animacy,-
    Lemma,2256,animacy,+
    ...
    $ rake proiel:semantic_tags:import FILE=tags.csv


`proiel:text:import`
--------------------

This task is used to import _new_ base texts. The import will create a new
source object in the database. If one already exists, an exception will be
raised.

Example:

    $ rake proiel:text:import FILE=wulfila-gothicnt.xml

`proiel:inflections:import`
---------------------------

This task imports inflections. The data should be a comma separated
files with the following fields:

  * Language code
  * Lemma and optional variant number separated by a hash mark (#)
  * Part of speech
  * Inflected form
  * Positional tag(s) with morphology

Example:

    got,and-haitan,,andhaihaist,V-2suia-----

`proiel:inflections:export`
---------------------------

This task exports inflections. The format is the same as for
`proiel:inflections:import`.

`proiel:bilingual_dictionary:create`
------------------------------------

This task creates a dictionary of lemmas in the specified source with
their presumed equivalents in the Greek original. The `SOURCE` should be
the ID of the source to process. The lemmas will be referred to
using the database ID unless `FORMAT`=`human` is set, in which case their
export_form will be used instead. The dictionary is written to the
specified `FILE`.

The `METHOD` argument specifies the statistical method used to compute
collocation significance. The default is `zvtuuf`, which is a log
likelihood measure. Other options are `dunning`, which is Dunning's
log likelihood measure, and `fisher`, which is Fisher's exact
test. The latter method requires a working installation of R and the
rsruby gem.

The format of the resulting dictionary file is the following. The
first line contains the number of aligned chunks (i.e. Bible verses)
the dictionary was based on. Next there is one line for each lemma of
the processed source, containing comma separated data: first, the
lemma export form or ID, next the frequency of that lemma, and then
the thirty most plausible Greek original lemmas (most plausible
first). For each Greek lemma, the export form or ID is given, followed
by semi-colon separated information about that lemma and its
co-occurrence with the given translation lemma. The following
information is available:

  1. `cr` = a measure combining the rank of the translation lemma as a
  correspondence to the original lemma, and the original lemma as a
  correspondence to the translation lemma. The value is 1 divided by
  the square root of the product of the two ranks, so if both lemma's
  are the best correspondences to each other, the value will be
  1.0. This is the value used to rank the translations.
  2. `sign` = the
  log likelihood or significance value returned by the given
  statistical test. This is used to produce the ranks that go into `cr`.
  3. `cooccurs` = the number of times the two lemmas co-occur in the same
  aligned chunk.
  4. `occurs` = the number of times the given Greek
  lemma occurs in the chunks that went into the creation of the
  dictionary.

Thus

    misso,freq=42,ἀλλήλων{cr=1.0;sign=13.6667402646542;cooccurs=33;occurs=36}

means that the Gothic lemma `misso` occurs 42 times, its best Greek
equivalent is ἀλλήλων, their combined rank is 1.0, the log likelihood
value of the collocation is 13.66, the two lemmas co-occur 33 times,
and ἀλλήλων occurs 36 times.

`proiel:token_alignments:set`
-----------------------------

This tasks generates token alignments, guessing at which Greek tokens
correspond to which translation tokens. The task requires that a
dictionary file (on ID format) is present in the lib directory, and
the name of this file must be given as the value of the `DICTIONARY`
argument.

Either a `SOURCE` or a (sequence of) `SOURCE_DIVISION`(s) to be
aligned must be specified. SOURCE_DIVISION can take single
source_division ID or a range of IDs (e.g. 346--349). The default
`FORMAT` is `db`, which writes the alignments to the database. Other
formats are `csv` and `human`, which write the alignments on CSV or
human-readable format to standard out, or to the specified `FILE`.