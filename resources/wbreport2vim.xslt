<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:transform
     version="1.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>
<xsl:output
  encoding="UTF-8"
  method="text"
  omit-xml-declaration="yes"
  doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"
/>

<xsl:template match="/">
let b:schema_report = {}
<xsl:call-template name="table-definitions"/>
<xsl:call-template name="view-definitions"/>
</xsl:template>

<xsl:template name="boolean">
    <xsl:param name="value"/>
    <xsl:choose><xsl:when test="$value = 'false'">0</xsl:when><xsl:when test="$value = 'true'">1</xsl:when><xsl:otherwise>0</xsl:otherwise></xsl:choose>
</xsl:template>

<xsl:template name="columns-definitions">
    <xsl:param name="table"/>
    <xsl:for-each select="column-def">
        <xsl:variable name="column"><xsl:value-of select="@name"/></xsl:variable>
        let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>'] = {}
        let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['name'] = '<xsl:value-of select="@name"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['type'] = <xsl:value-of select="./java-sql-type"/>
        let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['primary-key'] = <xsl:call-template name="boolean"><xsl:with-param name="value" select="./primary-key"/></xsl:call-template>
        let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['references'] = {}
        <xsl:for-each select="references">
            let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['references']['schema'] = '<xsl:value-of select="./table-schema"/>'
            let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['references']['catalog'] = '<xsl:value-of select="./table-catalog"/>'
            let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['references']['table'] = '<xsl:value-of select="./table-name"/>'
            let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['references']['column'] = '<xsl:value-of select="./column-name"/>'
            let b:schema_report['<xsl:value-of select="$table"/>']['columns']['<xsl:value-of select="$column"/>']['references']['constraint'] = '<xsl:value-of select="./constraint-name"/>'
        </xsl:for-each>
    </xsl:for-each>
</xsl:template>

<xsl:template name="foreign-keys">
    <xsl:param name="table"/>
    <xsl:for-each select="foreign-keys/foreign-key">
        <xsl:variable name="key"><xsl:value-of select="./constraint-name"/></xsl:variable>
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>'] = {}
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>']['table'] = {}
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>']['table']['name'] = '<xsl:value-of select="./references/table-name"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>']['table']['schema'] = '<xsl:value-of select="./references/table-schema"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>']['table']['catalog'] = '<xsl:value-of select="./references/table-catalog"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>']['source-column'] = '<xsl:value-of select="./source-columns/column"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys']['<xsl:value-of select="$key"/>']['dest-column'] = '<xsl:value-of select="./referenced-columns/column"/>'
    </xsl:for-each>
</xsl:template>

<xsl:template name="table-definitions">
    <xsl:for-each select="/schema-report/table-def">
        <xsl:variable name="table"><xsl:value-of select="@name"/></xsl:variable>
        let b:schema_report['<xsl:value-of select="$table"/>'] = {}
        let b:schema_report['<xsl:value-of select="$table"/>']['type'] = 'table'
        let b:schema_report['<xsl:value-of select="$table"/>']['schema'] = '<xsl:value-of select="./table-schema"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['catalog'] = '<xsl:value-of select="./table-catalog"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['name'] = '<xsl:value-of select="@name"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['columns'] = {}
        <xsl:call-template name="columns-definitions">
            <xsl:with-param name="table" select="$table"></xsl:with-param>
        </xsl:call-template>
        let b:schema_report['<xsl:value-of select="$table"/>']['foreign-keys'] = {}
        <xsl:call-template name="foreign-keys">
            <xsl:with-param name="table" select="$table"></xsl:with-param>
        </xsl:call-template>
    </xsl:for-each>
</xsl:template>

<xsl:template name="view-definitions">
    <xsl:for-each select="/schema-report/view-def">
        <xsl:variable name="table"><xsl:value-of select="@name"/></xsl:variable>
        let b:schema_report['<xsl:value-of select="$table"/>'] = {}
        let b:schema_report['<xsl:value-of select="$table"/>']['name'] = '<xsl:value-of select="@name"/>'
        let b:schema_report['<xsl:value-of select="$table"/>']['type'] = 'view'
        let b:schema_report['<xsl:value-of select="$table"/>']['columns'] = {}
        <xsl:call-template name="columns-definitions">
            <xsl:with-param name="table" select="$table"></xsl:with-param>
        </xsl:call-template>
    </xsl:for-each></xsl:template>
</xsl:transform>
