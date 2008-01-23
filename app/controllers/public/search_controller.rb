class SearchController < ApplicationController  

  helper TagsHelper

  SEARCHES = []

  def self.search(&block)
    SEARCHES << block
  end

  protected

  #############################################
  # XXX add yours searches here
  #############################################

  search do |query|
    Article.find_by_contents(query)
  end

  search do |query|
    Profile.find_by_contents(query)
  end

  search do |query|
    Product.find_by_contents(query)
  end

  # auxiliary method to search in all defined searches and collect the results 
  def search(query)
    SEARCHES.inject([]) do |acc,finder|
      acc += finder.call(query)
    end.sort_by do |hit|
      -(relevance_for(hit))
    end
  end

  public

  include SearchHelper

  def index
    @query = params[:query] || ''
    @filtered_query = remove_stop_words(@query)
    @results = search(@filtered_query)
  end

  def tags
    @tags = Tag.find(:all).inject({}) do |memo,tag|
      memo[tag.name] = tag.taggings.count
      memo
    end
  end

  def tag
    @tag = Tag.find_by_name(params[:tag])
    @tagged = @tag.taggings.map(&:taggable)
  end

  def popup
    render :action => 'popup', :layout => false
  end

end
