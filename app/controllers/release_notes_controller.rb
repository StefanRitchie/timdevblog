class ReleaseNotesController < ApplicationController

  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_release_note, only: [:show, :edit]

  def index
    @release_notes = ReleaseNote.all
  end
  
  def new
    @release_note = ReleaseNote.new
    @release_note.release_note_items.build
  end

  def create
    @release_note = ReleaseNote.new(release_note_params)

    begin
      if @release_note.save!
        respond_to do |format|
          flash[:notice] = 'Release Note created'
          format.html {redirect_to @release_note}
        end
      end
    rescue ActiveRecord::RecordInvalid => invalid
      respond_to do |format|
        format.html {render new_release_note_path}
      end
    end

  end

  def update
    release_note = set_release_note
    if release_note.update(release_note_params)
      respond_to do |format|
        flash[:notice] = 'Release Note updated'
        format.html {redirect_to @release_note}
      end
    end
  end
  
  def show
  end

  def edit
  end

  def destroy
    release_note = set_release_note
    release_note.release_note_items.each do |rni|
      rni.destroy
    end
    if release_note.destroy
      respond_to do |format|
        flash[:notice] = 'Release Note deleted'
        format.html {redirect_to :release_notes}
      end
    end
  end

  def publish_toggle
    release_note = set_release_note
    if release_note.published
      if release_note.update(published: false)
        respond_to do |format|
          flash[:notice] = 'Release Note unpublished'
          format.html {redirect_to :release_notes}
        end
      end
    else
      if release_note.update(published: true)
        respond_to do |format|
          flash[:notice] = 'Release Note published'
          format.html {redirect_to :release_notes}
        end
      end
    end
  end

  def tim_rn_signature
    sig = ENV['TIM_RN_RELEASE_NOTES_KEY']
    Obfuscate.new.encrypt(sig)
  end

  def notify
    release_note = set_release_note
    through_link =  ENV['TIM_RELEASE_NOTES_URL'] + "/release_notes/" + release_note.id.to_s

    domains = ENV['WEBHOOK_URLS'].split(',')
    domains.each do |domain|

      puts "## Domain: #{domain}"

      url = URI.parse(domain)
      req = Net::HTTP::Post.new(url.request_uri, 'Content-Type' => 'application/json', 'x-tim-release-note' => tim_rn_signature)
      #req.body = { origin: "TIM-Release-Notes", title: release_note.title, rnid: release_note.id, icon_emoji: ":beers:", text: "*There's a new version of TIM!*" + "\nHave a read through the release notes:\n <" + through_link  + "|" + release_note.title + "&gt;"}.to_json
      req.body = { origin: "TIM-Release-Notes", title: release_note.title, rnid: release_note.id, icon_emoji: ":beers:", text: "*There's a new version of TIM!*", "attachments": [{"actions": [{"type": "button", "text": release_note.title, "url": through_link }]}]}.to_json
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == "https")
      response = http.request(req)

      puts "## Request: #{req.body}"
      puts "## Response: #{response.body}"

    end

    notifier = Slack::Notifier.new Rails.application.credentials[:slack][:general]

    attachment_payload = {
        "fields": [
            {
                "title": "There's a new version of TIM!",
                "value": "Have a read through the release notes:\n<#{through_link} |#{release_note.title}>",
                "short": false
            }
        ]
    }
    notifier.post icon_emoji: ":beers:", attachments: [attachment_payload]

    respond_to do |format|
      flash[:notice] = 'Notification Sent'
      format.html {redirect_to :release_notes}
    end
  end

  def new_features
    @release_notes = ReleaseNote.new_features
  end

  def enhancements
    @release_notes = ReleaseNote.enhancements
  end

  def bug_fixes
    @release_notes = ReleaseNote.bug_fixes
  end
  
  private
  
  def set_release_note
    @release_note = ReleaseNote.find(params[:id])
  end

  def release_note_params
    params.require(:release_note).permit(:id, :user_id, :title, :intro, :outro, :release_date, :published,
                                         release_note_items_attributes: [:id, :user_id, :release_note_id, :change_type_id, :change_title, :change_details, :_destroy])
  end
end
