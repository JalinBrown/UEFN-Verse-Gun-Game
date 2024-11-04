#*******************************************************************************
#/file      game_manager.verse
#/author    Jalin A. Brown
#/date   	10/23/2024
#
# Practice Makes Perfection
#
#/brief Description:
# - Implements the game_manager class for controlling player weapon progression.
# - Handles player eliminations and weapon assignments.
# - Ensures that players retain their last weapon after respawn.
# - Manages interactions with sentry devices.
# - Activates the end game when the win conditions are met.
# - Inspired by 'WarforgeXP' on youtube.com: https://www.youtube.com/@WarforgeXP
#
# Built and tested on Windows x86
#*******************************************************************************

#-------------------------------------------------------------------------------
# Includes:
#-------------------------------------------------------------------------------
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Teams }
using { /Fortnite.com/Game }
# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

#-------------------------------------------------------------------------------
# Game manager class controlling player weapon progression and game loop.
#-------------------------------------------------------------------------------
# A Verse-authored creative device that can be placed in a level
game_manager := class(creative_device):
    #-------------------------------------------------------------------------------
    # Static Variables
    #-------------------------------------------------------------------------------
    var playerMap : [player]int = map{} #Map to store each player and their associated weapon/score value.
    var winCount : int = 0              #Total number of weapons available to grant before finally winning.

    @editable #Array of sentry devices that will be linked and managed within the game.
    var sentries_devices : []sentry_device = array{}

    @editable #Array of item granter devices to give players each weapon as they progress.
    var weaponGranters_devices : []item_granter_device = array{} # Initialize as an empty array

    @editable #Device that triggers once the end of the game conditions are met.
    var endGame_device : end_game_device = end_game_device{}

    #-------------------------------------------------------------------------------
    # /OnBegin
    #
    # /brief  - Initializes the game by setting the number of weapon granters,
    #           loading players, and sentry bot behavior.
    # /param  - (none)
    # /return - void
    #-------------------------------------------------------------------------------
    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        set winCount = weaponGranters_devices.Length
        InitPlayers()
        InitTest()

    #-------------------------------------------------------------------------------
    # /InitPlayers
    #
    # /brief  - Initializes players in the game and assigns them initial weapons.
    # /param  - (none)
    # /return - void
    #-------------------------------------------------------------------------------
    InitPlayers() : void=
        Players := GetPlayspace().GetPlayers() # Get the list of all players in the game

        # Loop through all players and initialize their weapon value to 0
        for(Player_Container : Players, Fort_Char := Player_Container.GetFortCharacter[]):
            # Add player to the map with an initial score of 0
            if(set playerMap[Player_Container] = 0, Score_Value := playerMap[Player_Container]):
                # Subscribe to player elimination events
                Fort_Char.EliminatedEvent().Subscribe(PlayerEliminated_Event) # Use subscribe to listen for eliminations when called
                Print("Storing players into the playerMap")
                # Grant player their first weapon
                GrantWeapon(Player_Container, Score_Value)

    #-------------------------------------------------------------------------------
    # /GrantWeapon
    #
    # /brief  - Grants a weapon to the player based on their current score.
    # /param  - Player_Key : player - The player receiving the weapon.
    # /param  - Score_Value : int   - The player's current score determining which weapon to grant.
    # /return - void
    #-------------------------------------------------------------------------------
    GrantWeapon(Player_Key: player, Score_Value: int) : void=
        Print("Granting Weapon to Player")
        # Get weapon granter based on player's score
        if(Current_Item_Granted := weaponGranters_devices[Score_Value]):
            Print("Granted Weapon to Player")
            Current_Item_Granted.GrantItem(Player_Key) # Grant the weapon to the player

    #-------------------------------------------------------------------------------
    # /PlayerEliminated_Event
    #
    # /brief  - Event handler for when a player is eliminated. Advances the player's weapon.
    #         - elimination_result and .EliminatingCharacter are built in to UEFN
    # /param  - Result : elimination_result - The result of the elimination event.
    # /return - void
    #-------------------------------------------------------------------------------
    PlayerEliminated_Event(Result : elimination_result) : void=
        # Identify who eliminated the player
        Eliminator := Result.EliminatingCharacter
        # Ensure it's a valid elimination
        if(Fort_Char := Eliminator?, Eliminiating_Player := Fort_Char.GetAgent[]):
            Print("Granting next weapon to the player")

    #-------------------------------------------------------------------------------
    # /IncrementPlayerScore
    #
    # /brief  - Increments the player's score and checks if the end game condition is met.
    # /param  - Agent : agent - The player or agent whose score is incremented.
    # /return - void
    #-------------------------------------------------------------------------------
    IncrementPlayerScore(Agent : agent) : void=
        var WeaponIndex : int = 0
        # Cast the agent to a player and get their current weapon score
        if(Player := player[Agent], WeaponScore := playerMap[Player]):
            set WeaponIndex = WeaponScore + 1 # Increment the player's weapon score
            CheckEndGame(Agent, WeaponIndex)  # Check if this ends the game

        if(Player := player[Agent], set playerMap[Player] = WeaponIndex):
            # Now that the score is updated, grant the next weapon
            GrantWeapon(Player, WeaponIndex)

    #-------------------------------------------------------------------------------
    # /InitTest
    #
    # /brief  - Initializes test behavior by subscribing to sentry eliminations.
    # /return - void
    #-------------------------------------------------------------------------------
    InitTest() : void=
        for(Sentry : sentries_devices):
            # Subscribe to sentry elimination events
            Sentry.EliminatedEvent.Subscribe(TestPlayerElimination)

    #-------------------------------------------------------------------------------
    # /TestPlayerElimination
    #
    # /brief  - Event handler for when a sentry is eliminated, incrementing player score.
    # /param  - Agent : ?agent - The agent that eliminated the sentry.
    # /return - void
    #-------------------------------------------------------------------------------
    TestPlayerElimination(Agent : ?agent) : void=
        Print("Sentry eliminated!")
        # Ensure the agent is valid and proceed to increment their score
        if(Player := Agent?):
            IncrementPlayerScore(Player)

    #-------------------------------------------------------------------------------
    # /CheckEndGame
    #
    # /brief  - Checks if the player has reached the required score to win the game.
    # /param  - Player : agent     - The player whose score is being checked.
    # /param  - WeaponIndex : int  - The player's current weapon score.
    # /return - void
    #-------------------------------------------------------------------------------
    CheckEndGame(Player : agent, WeaponIndex : int) : void=
        # Check if the player's score reaches the win condition
        if(WeaponIndex >= winCount):
            endGame_device.Activate(Player) # Trigger the end game for the winning player
#-------------------------------------------------------------------------------