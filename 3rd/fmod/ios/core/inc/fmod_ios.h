#ifndef _FMOD_IOS_H
#define _FMOD_IOS_H

/*
[ENUM]
[
    [DESCRIPTION]
    Control whether the sound will use a the dedicated hardware decoder or a software codec.
 
    [REMARKS]
    Every devices has a single hardware decoder and unlimited software decoders.

    [SEE_ALSO]
]
*/
typedef enum FMOD_AUDIOQUEUE_CODECPOLICY
{
    FMOD_AUDIOQUEUE_CODECPOLICY_DEFAULT,            /* Try hardware first, if it's in use or prohibited by audio session, try software. */
    FMOD_AUDIOQUEUE_CODECPOLICY_SOFTWAREONLY,       /* kAudioQueueHardwareCodecPolicy_UseSoftwareOnly ~ try software, if not available fail. */
    FMOD_AUDIOQUEUE_CODECPOLICY_HARDWAREONLY,       /* kAudioQueueHardwareCodecPolicy_UseHardwareOnly ~ try hardware, if not available fail. */
    
    FMOD_AUDIOQUEUE_CODECPOLICY_FORCEINT = 65536    /* Makes sure this enum is signed 32bit */
} FMOD_AUDIOQUEUE_CODECPOLICY;

#endif /* _FMOD_IOS_H */
