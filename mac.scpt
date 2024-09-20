on MMSecretVar()
    try
        set MMSecret to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation MMSecret")
    on error
        --Change what's in the quotes below to the name or ARN of your AWS Secrets Manager secret if coding in here.
        set MMSecret to "jamfSecret"
    end try
    return MMSecret
end MMSecretVar

on getInvitationID()
    --If manually setting an invitation ID, set here and use the following command to enable:
    --defaults write com.amazon.dsx.ec2.enrollment.automation invitationID "INVITATIONIDGOESHERE"
    try
        --If setting inline, uncomment the below and remove the defaults line.
        --set theInvitationID to ""
        set theInvitationID to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation invitationID")
        get theInvitationID
    on error
        set theInvitationID to false
    end try
    return theInvitationID
end getInvitationID

if macOSMajor is greater than or equal to 13 then
    -- Ventura runtime starts here.
    tell application "System Events" to tell process settingsApp
        repeat
            try
                get value of static text 1 of UI element 1 of row 2 of table 1 of scroll area 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
                exit repeat
            on error
                try
                    -- Sonoma b1
                    get value of static text 1 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
                    exit repeat
                end try
                delay 0.2
            end try
        end repeat
        delay 0.2
        try
            set profileCell to row 2 of table 1 of scroll area 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
        on error
            try
                -- Sonoma b1
                set profileCell to row 2 of table 1 of scroll area 1 of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
            on error
                -- Sequoia 15.0
                set profileCell to row 2 of outline 1 of scroll area 1 of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
            end try
        end try
        set {xPosition, yPosition} to position of profileCell
        set {xSize, ySize} to size of profileCell
        set clickInstalled to my clickCheck(pathPrefix)
        if clickInstalled is not true then
            my visiLog("Status", "Installing helper app…", localAdmin, adminPass)
            try
                do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
            on error
                -- If using a different user than default, change Homebrew ownership.
                my brewPrivilegeRepair(archType, localAdmin, adminPass)
                delay 0.5
                do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
            end try
            my visiLog("Status", "Helper app installed, please wait…", localAdmin, adminPass)
        end if
        if useDEPNotify is true then
            do shell script "killall -m DEPNotify" user name localAdmin password adminPass with administrator privileges
        end if
        delay 0.2
        tell application settingsApp to activate
        do shell script pathPrefix & "cliclick dc:" & (xPosition + (xSize div 2)) & "," & (yPosition + (ySize div 2))
        delay 0.2
        if useDEPNotify is true then
            do shell script DEPNotifyPath & "DEPNotify.app/Contents/MacOS/DEPNotify -fullScreen > /dev/null 2>&1 &"
        end if
        my visiLog("Status", "Continuing enrollment process…", localAdmin, adminPass)
        repeat
            try
                click button 1 of group 1 of sheet 1 of window 1
                exit repeat
            on error
                delay 0.5
            end try
        end repeat
        delay 0.2
        my elementCheck("profile", "System Settings")
        my visiLog("Status", "Authorizing profile…", localAdmin, adminPass)
        delay 0.2
        click button "Install" of sheet 1 of window 1
        delay 0.2
        set the clipboard to adminPass
        -- Checks to make sure the security window appears before typing credentials.
        my securityCheckVentura()
        -- Pastes the administrator password, then presses Return.
        keystroke "v" using command down
        delay 0.1
        if stageHand is "1" then
            key code 48 using shift down
            delay 0.1
            keystroke "a" using command down
            delay 0.1
            set the clipboard to localAdmin
            keystroke "v" using command down
            delay 0.1
        end if
        keystroke return
        -- Immediately clear the clipboard of the password.
        set the clipboard to null
        delay 0.1
        set the clipboard to null
        my visiLog("Status", "Profile authorized, awaiting enrollment confirmation…", localAdmin, adminPass)
        repeat
            try
                set managedValidationText to (get value of static text 1 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
            on error
                try
                    set managedValidationText to (get value of static text 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
                on error
                    set managedValidationText to ""
                end try
            end try
            if managedValidationText contains "managed" then
                do shell script "killall -m System\\ Settings" user name localAdmin password adminPass with administrator privileges
                exit repeat
            else
                delay 0.5
            end if
            try
                set enrollmentCLI to (do shell script "/usr/bin/profiles status -type enrollment | awk '/MDM/' | grep 'enrollment: Yes' ")
            on error
                set enrollmentCLI to null
            end try
            if enrollmentCLI contains "Yes" then
                do shell script "killall -m System\\ Settings" user name localAdmin password adminPass with administrator privileges
                exit repeat
            end if
        end repeat
    end tell
else
    -- macOS 12 and below use this set of instructions.
    tell application "System Events" to tell process "System Preferences"
        -- Make sure the Install button is available before continuing.
        repeat
            if (exists button "Install…" of scroll area 1 of window 1) then
                exit repeat
            else
                delay 0.5
            end if
        end repeat
        -- Clicks the first "Install…" button…
        my visiLog("Status", "Authorizing profile…", localAdmin, adminPass)
        click button "Install…" of scroll area 1 of window 1
        delay 0.2
        -- Checks for the first prompt, containing the word "profile" means it's ready.
        my elementCheck("profile", "System Preferences")
        click button "Install" of sheet 1 of window 1
        delay 0.2
        -- Checks for a string in the next prompt.
        if (my elementCheck("Are you sure you want to install profile", "System Preferences")) is not false then
            click button "Install" of window 1
        else
            display notification "Enrollment failed. Please check the profile and try again."
            error -128
        end if
        delay 0.2
        set the clipboard to adminPass
        -- Checks to make sure the security window appears before typing credentials.
        my securityCheck()
        -- Types the administrator password, then presses Return.
        keystroke "v" using command down
        delay 0.1
        if stageHand is "1" then
            key code 48 using shift down
            delay 0.1
            keystroke "a" using command down
            delay 0.1
            set the clipboard to localAdmin
            delay 0.1
            keystroke "v" using command down
            delay 0.1
        end if
        keystroke return
        -- Immediately clear the clipboard of the password.
        set the clipboard to null
        delay 0.2
        set the clipboard to null
        keystroke return
        delay 0.2
        my visiLog("Status", "Profile authorized, awaiting enrollment confirmation…", localAdmin, adminPass)

        -- Checks to make sure the profile is successfully installed.
        repeat
            try
                set managedValidationText to (get value of static text 1 of scroll area 1 of window 1)
            on error
                set managedValidationText to ""
            end try
            if managedValidationText contains "managed" then
                do shell script "killall -m 'System Preferences'" user name localAdmin password adminPass with administrator privileges
                exit repeat
            else
                delay 0.5
            end if
            try
                set enrollmentCLI to (do shell script "/usr/bin/profiles status -type enrollment | awk '/MDM/' | grep 'enrollment: Yes' ")
            on error
                set enrollmentCLI to null
            end try
            if enrollmentCLI contains "Yes" then
                do shell script "killall -m 'System Preferences'" user name localAdmin password adminPass with administrator privileges
                exit repeat
            end if
        end repeat
    end tell
end if

-- Additional helper functions below...

on clickCheck(pathPrefix)
    try
        do shell script pathPrefix & "cliclick -v"
        return true
    on error
        return false
    end try
end clickCheck

on brewPrivilegeRepair(archType, localAdmin, adminPass)
    if archType is equal to "arm" then
        do shell script "/opt/homebrew/bin/brew doctor" user name localAdmin password adminPass with administrator privileges
    else
        do shell script "/usr/local/bin/brew doctor" user name localAdmin password adminPass with administrator privileges
    end if
end brewPrivilegeRepair

on elementCheck(elementText, windowTitle)
    repeat until (exists window windowTitle)
        delay 0.5
    end repeat
    repeat until (exists (first static text whose value contains elementText) of window windowTitle)
        delay 0.5
    end repeat
end elementCheck

on securityCheckVentura()
    repeat until (exists window "System Settings")
        delay 0.5
    end repeat
end securityCheckVentura

on securityCheck()
    repeat until (exists window "System Preferences")
        delay 0.5
    end repeat
end securityCheck

on visiLog(logType, logMessage, localAdmin, adminPass)
    -- Add your custom logging implementation here.
    log logMessage
end visiLog

