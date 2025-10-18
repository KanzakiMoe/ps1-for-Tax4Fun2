# --------- User Configurable Section ---------
# Set your vsearch executable path (must be all English path)
$vsearch = 'O:\tax4fun_data\vsearch-2.30.0-win-x86_64\bin\vsearch.exe'
# Set your input fastq file (must be all English path)
$fastq = 'O:\tax4fun_data\raw\sample.fastq'
# Set your Tax4Fun2 reference data directory (must be all English path)
$refdata = 'O:\tax4fun_data\Tax4Fun2_ReferenceData_v2\Tax4Fun2_ReferenceData_v2'
# Output working directory (must be all English path)
$outdir = 'O:\tax4fun_data\vsearch_out'
# ---------------------------------------------

$prefix = "$outdir\sample"

# Create output directory if not exists
New-Item -ItemType Directory -Force -Path $outdir | Out-Null

# Clean temp files in reference data
docker run --rm -v O:\tax4fun_data\Tax4Fun2_ReferenceData_v2\Tax4Fun2_ReferenceData_v2:/data -v O:\tax4fun_data\vsearch_out:/input tax4fun2:latest rm -rf /data/temp/*

# 1. Convert fastq to fasta
if (!(Test-Path $fastq)) {
    Write-Host "Input fastq file does not exist: $fastq"
    exit 1
}
& $vsearch --fastq_filter $fastq --fastaout "$prefix.fasta" --fastq_qmax 93

# 2. Dereplication
& $vsearch --derep_fulllength "$prefix.fasta" --output "$prefix.derep.fasta" --sizeout --minuniquesize 2 --uc "$prefix.derep.uc"

# 3. OTU clustering (97% similarity)
& $vsearch --cluster_size "$prefix.derep.fasta" --id 0.97 --centroids "$prefix.otus.fasta" --uc "$prefix.otus.uc"

# 4. Generate OTU table
& $vsearch --usearch_global "$prefix.fasta" --db "$prefix.otus.fasta" --id 0.97 --otutabout "$prefix.otu_table.txt"

Write-Host "All vsearch output files are generated in $outdir"
Write-Host "Representative sequences: $prefix.otus.fasta"
Write-Host "OTU table: $prefix.otu_table.txt"

# 5. OTU table formatting fix:
$in = 'O:\tax4fun_data\vsearch_out\sample.otu_table.txt'
$out = 'O:\tax4fun_data\vsearch_out\sample.otu_table_fixed.txt'
"OTU_ID	Sample1" | Set-Content $out

Get-Content $in | Where-Object { $_ -notmatch '^#' -and $_ -ne '' } | ForEach-Object {
    $fields = $_ -split '\t'
    if ($fields.Count -ge 2) {
        $_ | Add-Content $out
    } elseif ($fields.Count -eq 1) {
        "$($_)`t1" | Add-Content $out
    }
}

Get-Content "O:\tax4fun_data\vsearch_out\sample.otus.fasta" | ForEach-Object {
    if ($_ -like ">*") {
        # Remove > and ;size=XX
        ">" + (($_ -replace "^>", "") -replace ";size=\d+", "")
    } else {
        $_
    }
} | Set-Content sample_fixed.otus.fasta

# 6. Run Tax4Fun2 runRefBlast in Docker
docker run --rm -v ${refdata}:/data -v ${outdir}:/input tax4fun2:latest Rscript -e "library(Tax4Fun2); runRefBlast(path_to_otus = '/input/sample_fixed.otus.fasta', path_to_reference_data = '/data', path_to_temp_folder = '/data/temp', database_mode = 'Ref100NR', use_force = TRUE, num_threads = 4)"

# 7. Run Tax4Fun2 makeFunctionalPrediction in Docker
docker run --rm -v ${refdata}:/data -v ${outdir}:/input tax4fun2:latest Rscript -e "library(Tax4Fun2); makeFunctionalPrediction(path_to_otu_table = '/input/sample.otu_table_fixed.txt', path_to_reference_data = '/data', path_to_temp_folder = '/data/temp', database_mode = 'Ref99NR', normalize_by_copy_number = TRUE, min_identity_to_reference = 0.97)"

Write-Host "Tax4Fun2 functional prediction finished. Check /data/temp in your reference data directory for results."