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

<xsl:template name="string-replace-all">
    <xsl:param name="text" />
    <xsl:param name="replace" />
    <xsl:param name="by" />
    <xsl:choose>
        <xsl:when test="contains($text, $replace)">
            <xsl:value-of select="substring-before($text,$replace)" />
            <xsl:value-of select="$by" />
            <xsl:call-template name="string-replace-all">
                <xsl:with-param name="text" select="substring-after($text,$replace)" />
                <xsl:with-param name="replace" select="$replace" />
                <xsl:with-param name="by" select="$by" />
            </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="$text" />
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template match="/">
    let b:macros = {}
    <xsl:call-template name="profiles"/>
</xsl:template>

<xsl:template name="profiles">
    <xsl:for-each select="//void[@property='macros']/void[@method='add']/object[@class='workbench.sql.macros.MacroDefinition']">
        <xsl:variable name="macro">
            <xsl:value-of select="./void[@property='name']/string"></xsl:value-of>
        </xsl:variable>
        <xsl:variable name="quot">'</xsl:variable>
        <xsl:variable name="quot2">''</xsl:variable>
        <xsl:variable name="new-line" select="'&#10;'"></xsl:variable>
        <xsl:variable name="sql1">
            <xsl:call-template name="string-replace-all">
                <xsl:with-param name="text" select="./void[@property='text']/string"></xsl:with-param>
                <xsl:with-param name="replace" select="$quot"></xsl:with-param>
                <xsl:with-param name="by" select="$quot2"></xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="sql2">
            <xsl:call-template name="string-replace-all">
                <xsl:with-param name="text" select="$sql1"></xsl:with-param>
                <xsl:with-param name="replace" select="$new-line"></xsl:with-param>
                <xsl:with-param name="by" select="'#NEWLINE#'"></xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        let b:macros['<xsl:value-of select="$macro"/>'] = {}
        let b:macros['<xsl:value-of select="$macro"/>']['name'] = '<xsl:value-of select="$macro"/>'
        let b:macros['<xsl:value-of select="$macro"/>']['sql'] = '<xsl:value-of select="$sql2"></xsl:value-of>'
    </xsl:for-each>
</xsl:template>
<xsl:template name="properties">
    <xsl:param name="profile"/>
    let b:profiles['<xsl:value-of select="$profile"/>']['props'] = {}
    <xsl:for-each select="./void[@property='connectionProperties']/object[@class='java.util.Properties']/void[@method='put']">
        let b:profiles['<xsl:value-of select="$profile"/>']['props']['<xsl:value-of select="./string[1]"/>'] = '<xsl:value-of select="./string[2]"/>'
    </xsl:for-each>
</xsl:template>
</xsl:transform>
