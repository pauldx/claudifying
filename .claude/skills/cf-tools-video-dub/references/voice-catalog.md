# Edge TTS Voice Catalog

## Recommended Voices for Video Dubbing

### English — United States
| Voice ID | Name | Gender | Style |
|----------|------|--------|-------|
| `en-US-AndrewNeural` | Andrew | Male | Professional, clear (DEFAULT) |
| `en-US-AndrewMultilingualNeural` | Andrew Multilingual | Male | Multi-language capable |
| `en-US-GuyNeural` | Guy | Male | Casual, friendly |
| `en-US-DavisNeural` | Davis | Male | Deep, authoritative |
| `en-US-JennyNeural` | Jenny | Female | Professional, neutral |
| `en-US-AriaNeural` | Aria | Female | Conversational, warm |
| `en-US-SaraNeural` | Sara | Female | Young, energetic |

### English — United Kingdom
| Voice ID | Name | Gender | Style |
|----------|------|--------|-------|
| `en-GB-RyanNeural` | Ryan | Male | Formal, presenter |
| `en-GB-SoniaNeural` | Sonia | Female | Professional, BBC style |

### Other Languages (for translation dubbing)
| Voice ID | Language | Gender |
|----------|----------|--------|
| `hi-IN-MadhurNeural` | Hindi | Male |
| `hi-IN-SwaraNeural` | Hindi | Female |
| `es-ES-AlvaroNeural` | Spanish | Male |
| `fr-FR-HenriNeural` | French | Male |
| `de-DE-ConradNeural` | German | Male |
| `ja-JP-KeitaNeural` | Japanese | Male |

## SSML Rate Control

Edge TTS `rate` parameter controls speech speed:

| Rate | Effect | Use Case |
|------|--------|----------|
| `+30%` | Much faster | Fit long text into short slot |
| `+15%` | Faster | Slightly compressed |
| `+0%` | Normal | Default TTS speed |
| `-15%` | Slower | Relaxed narration |
| `-25%` | Much slower | Match longer video durations |
| `-30%` | Very slow | Maximum duration stretching |
| `-35%` | Extremely slow | Still sounds natural, near limit |

## Key Rules
- Always lock `pitch="+0Hz"` for consistency
- Always lock `volume="+0%"` for consistency
- Let `loudnorm` ffmpeg filter handle final volume
- Rate range: `-50%` to `+100%` (stay within `-35%` to `+30%` for natural sound)
