# gradcorrect

BIDS app for correcting gradient non-linearities. Saves corrected images as a mirrored BIDS dataset, along with warp and intensity-correction fields.

## Running with Pixi

Install Pixi:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

Then clone this repository and run:

```bash
pixi run gradcorrect -- <bids_dir> <output_dir> <participant|group> --grad_coeff_file <grad_coeff_file> [options]
```

For example:

```bash
pixi run gradcorrect -- \
    /path/to/bids \
    /path/to/output \
    participant \
    --grad_coeff_file /path/to/coeff.grad \
    --participant_label 01
```

The `--` separates Pixi arguments from the BIDS App arguments. Everything after `--` is passed directly to the application.

### Required arguments

| Argument                   | Description                                                              |
| -------------------------- | ------------------------------------------------------------------------ |
| `bids_dir`                 | Input BIDS dataset.                                                      |
| `output_dir`               | Directory where the corrected BIDS dataset will be written.              |
| `participant` or `group`   | BIDS analysis level.                                                     |
| `--grad_coeff_file <file>` | Gradient coefficient file describing the scanner gradient non-linearity. |

### Optional arguments

| Argument                                    | Description                                                                                                             |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `--participant_label <label> [<label> ...]` | Process only the specified participant(s).                                                                              |
| `--only_matching <search_string>`           | Only process images whose filenames contain the given string (e.g. `2RAGE` to process only MP2RAGE and SA2RAGE images). |

## Running with Docker

```bash
docker run --rm \
    -v /path/to/bids:/bids:ro \
    -v /path/to/output:/out \
    -v /path/to/coeffs:/coeffs:ro \
    khanlab/gradcorrect:latest \
    /bids /out participant \
    --grad_coeff_file /coeffs/coeff.grad \
    --participant_label 01
```

## Running with Singularity / Apptainer

```bash
apptainer run \
    docker://khanlab/gradcorrect:latest \
    /path/to/bids \
    /path/to/output \
    participant \
    --grad_coeff_file /path/to/coeff.grad \
    --participant_label 01
```

or

```bash
singularity run \
    docker://khanlab/gradcorrect:latest \
    /path/to/bids \
    /path/to/output \
    participant \
    --grad_coeff_file /path/to/coeff.grad \
    --participant_label 01
```



