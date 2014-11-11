require 'rubygems'
require 'sinatra'
require 'pry'

#no alerts when hitting and busting or hitting to blackjack, extra alerts otherwise

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'password_password' 

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_CASH_AMOUNT = 500

helpers do

  def calculate_total(cards)
    arr = cards.map{ |e| e[1] }

    total = 0
    arr.each do |value|
      if value == "ace"
        total += 11
      elsif value.to_i == 0
        total += 10
      else
        total += value.to_i
      end
    end

    arr.select{ |e| e == "ace"}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end
    total
  end

  def winner!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:cash] = session[:cash].to_i + session[:wager].to_i
    @winner = "#{msg} You now have $#{session[:cash]}."
  end

  def loser!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:cash] = session[:cash].to_i - session[:wager].to_i
    @loser = "#{msg} You now have $#{session[:cash]}."
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @winner = "#{msg}"
  end

  def card_image(card)#[['H', '4'],['D','10']]
    suit = card[0]
    value = card[1]
    
    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def hide_card(card)
    show_card = card[1]

    card_image(show_card)
  end
end


before do
  @show_hit_or_stay_buttons = true
  @hide_dealer_cards = true
  @play_again = false
end


get '/' do
  if session[:player_name]
    redirect '/game'
  else 
    redirect '/new_player'
  end
end


get '/new_player' do
  session[:cash] = INITIAL_CASH_AMOUNT
  erb :new_player
end


post '/new_player' do
  if params[:player_name].empty?
    @error = "Please enter your name."
    halt erb(:new_player)
  end

  session[:player_name] = params[:player_name]
  redirect '/bet'
end


get '/bet' do
  session[:wager] = nil
  erb :bet
end


post '/bet' do
  if params[:wager].nil? || params[:wager].to_i == 0 || params[:wager].to_i < 0
    @error = "Please enter an amount."
    halt erb(:bet)
  elsif params[:wager].to_i > session[:cash]
    @error = "You cannot bet more than you have."
    halt erb(:bet)
  else
    session[:wager] = params[:wager].to_i
    redirect '/game'
  end
end


get '/game' do
  session[:turn] = session[:player_name]

  suits = ['hearts', 'diamonds', 'clubs', 'spades']
  values = ['2','3','4','5','6','7','8','9','10','jack','queen','king','ace']
  
  session[:deck] = suits.product(values).shuffle!

  session[:player_cards] = []
  session[:dealer_cards] = []
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop

  if calculate_total(session[:player_cards]) == BLACKJACK_AMOUNT
    winner!("Blackjack baby! Well played.")
  end

  session[:player_total] = calculate_total(session[:player_cards])
  session[:dealer_total] = calculate_total(session[:dealer_cards])

  erb :game
end


post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop

  player_total = calculate_total(session[:player_cards])

  if player_total > BLACKJACK_AMOUNT
    loser!("Busted! Sorry about your luck, #{session[:player_name]}.")
  elsif player_total == BLACKJACK_AMOUNT
    winner!("Blackjack baby! Well played, #{session[:player_name]}")
  end

  erb :game, layout: false
end


post '/game/player/stay' do
  @success = "#{session[:player_name]} has chosen to stay."
  @show_hit_or_stay_buttons = false

  redirect '/game/dealer'
end


get '/game/dealer' do 
  session[:turn] = "dealer"

  dealer_total = calculate_total(session[:dealer_cards])
  @show_hit_or_stay_buttons = false
  @hide_dealer_cards = false
  
  if dealer_total == BLACKJACK_AMOUNT
    loser!("Dealer has blackjack. Better luck next time, #{session[:player_name]}.")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("Dealer has busted. #{session[:player_name]} wins!")
  elsif dealer_total >= DEALER_MIN_HIT
    redirect '/game/winner'
  else
    @show_dealer_hit_button = true
  end

  erb :game, layout: false

end


post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/game/dealer'
end


get '/game/winner' do
  @show_hit_or_stay_buttons = false
  @hide_dealer_cards = false
  
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])

  if player_total < dealer_total
    loser!("Dealer has #{dealer_total}, you have #{player_total}. Better luck next time #{session[:player_name]}.")
  elsif player_total > dealer_total
    winner!("Dealer has #{dealer_total}, you have #{player_total}. Congratulations! #{session[:player_name]} wins!")
  else
    tie!("Dealer has #{dealer_total}, you have #{player_total}. Looks like we have a tie!")
  end

  erb :game, layout: false
end


get '/game_over' do
  erb :game_over
end

