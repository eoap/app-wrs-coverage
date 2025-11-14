
$namespaces:
  s: https://schema.org/
  calrissian: https://calrissian-cwl.github.io/schema#
schemas:
  - http://schema.org/version/9.0/schemaorg-current-http.rdf


# The software itself

s:name: Landsat WRS Coverage Workflow
s:description: Landsat WRS Coverage Workflow provides counts of WRS tiles
s:dateCreated: '2025-11-14'
s:license:
  '@type': s:CreativeWork
  s:identifier: CC-BY-4.0

# Discoverability and citation

s:keywords:
- CWL
- CWL Workflow
- Workflow
- Earth Observation
- Earth Observation application package

# Run-time environment
s:operatingSystem:
- Linux
- MacOS X
s:softwareRequirements:
- https://cwltool.readthedocs.io/en/latest/
- https://www.python.org/

# Current version of the software

s:softwareVersion: 0.1.0
s:softwareHelp:
  '@type': s:CreativeWork
  s:name: User Manual
  s:url: https://eoap.github.io/app-wrs-coverage/

# Publisher

s:publisher:
  '@type': s:Organization
  s:email: info@terradue.com
  s:identifier: https://ror.org/0069cx113
  s:name: Terradue Srl

# Authors & Contributors

s:author:
- '@type': s:Role
  s:roleName: Project Manager
  s:additionalType: http://purl.org/spar/datacite/ProjectManager
  s:author:
    '@type': s:Person
    s:affiliation:
      '@type': s:Organization
      s:identifier: https://ror.org/0069cx113
      s:name: Terradue
    s:email: fabrice.brito@terradue.com
    s:familyName: Brito
    s:givenName: Fabrice
    s:identifier: https://orcid.org/0009-0000-1342-9736

cwlVersion: v1.2
  
$graph:
  - class: Workflow
    id: wrs-coverage
    label: WRS Coverage Workflow
    doc: |
      A CWL workflow to generate Landsat WRS coverage
    requirements:
      InlineJavascriptRequirement: {}
      NetworkAccess:
        networkAccess: true
    inputs:
      collection-id:
        doc: |
          The collection ID to process
        label: Collection ID
        type: string
        default: "landsat-c2-l2"
    outputs:
      wrs-coverage-image:
        doc: |
          The WRS coverage image output
        label: WRS Coverage Image
        outputSource: wrs-coverage-step/wrs-coverage-image
        type: File
      wrs-coverage-parquet:
        doc: |
          The WRS coverage parquet output
        label: WRS Coverage Parquet
        outputSource: wrs-coverage-step/wrs-coverage-parquet
        type: File
    steps:
      wrs-coverage-step:
        label: WRS Coverage Step
        doc: |
          Step to run the WRS coverage tool
        in:
          collection-id: collection-id
        out:
          - wrs-coverage-image
          - wrs-coverage-parquet
        run: "#wrs-coverage-tool"
  - class: CommandLineTool
    id: wrs-coverage-tool
    requirements:
      EnvVarRequirement:
        envDef: {}
      NetworkAccess:
        networkAccess: true
    hints:
      DockerRequirement:
        dockerPull: docker.io/library/wrs-coverage
      calrissian:DaskGatewayRequirement:
        workerCores: 1
        workerCoresLimit: 1
        workerMemory: "1G"
        clusterMaxCores: 10
        clusterMaxMemory: "20G"
    baseCommand: ["wrs-coverage"]
    arguments: []
    inputs:
      collection-id:
        type: string
        inputBinding:
          position: 1
          prefix: "--collection-id"
    outputs:
      wrs-coverage-image:
        type: File
        outputBinding:
          glob: acq-by-wrs-tile.png
      wrs-coverage-parquet:
        type: File
        outputBinding:
          glob: acq-by-wrs-tile.parquet