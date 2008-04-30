# Controls modification of morphtags on a per sentence basis.
class MorphtagsController < ApplicationController
  before_filter :is_annotator?, :only => [:edit, :update]

  def show
    @sentence = Sentence.find(params[:annotation_id])
  end

  def edit
    @sentence = Sentence.find(params[:annotation_id])
    @language = @sentence.language

    @tags = @sentence.word_tokens.inject({}) do |tags, token|
      tags[token.id] = {}

      result, tags[token.id][:pick], *tags[token.id][:suggestions] = token.invoke_tagger

      # Figure out which morph+lemma-tag to use as the displayed value. Anything
      # already set in the editor or, if nothing there, in the morphtag field
      # trumphs whatever the tagger may decide to spew out. To have the state set
      # correctly, we pretend we don't have any data from the editor first, and
      # then check to see if any values given are different from what we determined
      # to be our choice. If it is different, then set to "annotated".
      if token.morphtag and token.lemma_id
        tags[token.id][:set] = token.morph_lemma_tag
        tags[token.id][:state] = :mannotated
      elsif tags[token.id][:pick]
        tags[token.id][:set] = tags[token.id][:pick]
        tags[token.id][:state] = :mguessed
      else
        if token.morphtag and not token.lemma_id
          tags[token.id][:set] = token.morph_lemma_tag 
        else
          tags[token.id][:set] = nil
        end
        tags[token.id][:state] = :munannotated
      end

      if x = params["morphtag-#{token.id}".to_sym] and y = params["lemma-#{token.id}".to_sym]
        xy = PROIEL::MorphLemmaTag.new("#{x}:#{y}")
        if tags[token.id][:set] != xy
          tags[token.id][:set] = xy
          tags[token.id][:state] = :mannotated
        end
      end

      tags
    end

    respond_to do |format|
      format.html { render :layout => false if request.xhr? } 
      format.js { render :layout => false }
    end
  end

  def update
    @sentence = Sentence.find(params[:annotation_id])

    if @sentence.is_reviewed? and not current_user.has_role?(:reviewer)
      flash[:error] = 'You do not have permission to update reviewed sentences'
      redirect_to :action => 'edit', :wizard => params[:wizard], :annotation_id => params[:annotation_id]
      return
    end

    Token.transaction(session[:user]) do
      # Cycle the parameters and check whether this one originated with us 
      # or with them...
      params.keys.reject { |key| !(key =~ /^morphtag-/) }.each do |key|
        token_id = key.sub(/^morphtag-/, '')
        new_morphtag = PROIEL::MorphTag.new(ActiveSupport::JSON.decode(params[key]))
        new_lemma = params['lemma-' + token_id]

        # FIXME: for now, insert this bit here to catch missing lemmata. When all existing
        # tokens have lemmata, move it to validation.
        unless new_lemma and new_lemma != ''
          flash[:error] = 'Missing lemma'
          redirect_to :action => 'edit', :wizard => params[:wizard], :annotation_id => params[:annotation_id]
          return
        end

        ml = PROIEL::MorphLemmaTag.new("#{new_morphtag.to_s}:#{new_lemma}")

        suggestions = params['orig-suggestions-' + token_id].split(',').collect { |s| PROIEL::MorphLemmaTag.new(s) }
        pick = PROIEL::MorphLemmaTag.new(params['pick-' + token_id])

        if ml == pick
          performance = :picked
        elsif suggestions.include?(ml)
          performance = :suggested
        elsif pick.nil? and suggestions.empty?
          performance = :failed
        else
          performance = :overridden
        end

        token = Token.find(token_id)

        # We don't want to update morphtag_performance unnecessarily, so
        # test if the morphtag actually changed before updating.
        if token.morph_lemma_tag != ml
          token.set_morph_lemma_tag!(ml)
          token.update_attributes!(:morphtag_performance => performance)
        end
      end
    end

    if params[:wizard]
      redirect_to :controller => :wizard, :action => :save_morphtags, :wizard => params[:wizard]
    else
      redirect_to :action => 'show'
    end
  rescue ActiveRecord::RecordInvalid => invalid 
    flash[:error] = invalid.record.errors.full_messages
    # FIXME: ensure that "edit" respects our current settings?
    redirect_to :action => 'edit', :wizard => params[:wizard]
  end
end
