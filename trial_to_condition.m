function condition = trial_to_condition(trialName)

trialName = string(trialName);

if endsWith(upper(trialName), "W")
    condition = "With Ahenema";
else
    condition = "Without Ahenema";
end

end