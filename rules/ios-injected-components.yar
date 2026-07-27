rule IOS_Injected_AntiDebug_DynamicLoad
{
    meta:
        description = "Injected component combines anti-debug and dynamic loading APIs"
        severity = "review"
    strings:
        $anti1 = "ptrace" ascii
        $anti2 = "PT_DENY_ATTACH" ascii
        $anti3 = "sysctl" ascii
        $load1 = "dlopen" ascii
        $load2 = "dlsym" ascii
        $load3 = "NSClassFromString" ascii
    condition:
        1 of ($anti*) and 1 of ($load*)
}

rule IOS_Injected_Sensitive_Data_APIs
{
    meta:
        description = "Component references two or more sensitive local data APIs"
        severity = "review"
    strings:
        $keychain = "SecItemCopyMatching" ascii
        $pasteboard = "UIPasteboard" ascii
        $contacts = "CNContactStore" ascii
        $photos = "PHPhotoLibrary" ascii
    condition:
        2 of them
}

rule IOS_Injected_Hardcoded_Bearer
{
    meta:
        description = "Component contains a bearer-style credential string"
        severity = "high"
    strings:
        $bearer = /Bearer [A-Za-z0-9._~+\/=-]{16,}/ ascii nocase
    condition:
        $bearer
}

rule IOS_Injected_Remote_Config
{
    meta:
        description = "Component references remote configuration or update indicators"
        severity = "review"
    strings:
        $a = "remoteConfig" ascii nocase
        $b = "remote_config" ascii nocase
        $c = "configURL" ascii nocase
        $d = "updateURL" ascii nocase
    condition:
        any of them
}
