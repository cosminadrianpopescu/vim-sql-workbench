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
let b:profiles = {}
<xsl:call-template name="profiles"/>
</xsl:template>

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

<xsl:template name="profiles">
    <xsl:for-each select="/java/object/void[@method='add']/object[@class='workbench.db.ConnectionProfile']">
        <xsl:variable name="profile">
            <xsl:choose>
                <xsl:when test="not(./void[@property='group']/string)"><xsl:value-of select="./void[@property='name']/string"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="./void[@property='group']/string"/>\<xsl:value-of select="./void[@property='name']/string"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="quot">'</xsl:variable>
        <xsl:variable name="quot2">''</xsl:variable>
        <xsl:variable name="profile_parsed">
            <xsl:call-template name="string-replace-all">
                <xsl:with-param name="text" select="$profile"></xsl:with-param>
                <xsl:with-param name="replace" select="$quot"></xsl:with-param>
                <xsl:with-param name="by" select="$quot2"></xsl:with-param>
            </xsl:call-template>
        </xsl:variable>
        let b:profiles['<xsl:value-of select="$profile_parsed"/>'] = {}
        let b:profiles['<xsl:value-of select="$profile_parsed"/>']['name'] = '<xsl:value-of select="$profile_parsed"/>'
        let b:profiles['<xsl:value-of select="$profile_parsed"/>']['type'] = '<xsl:value-of select="./void[@property='driverName']/string"/>'
        let b:profiles['<xsl:value-of select="$profile_parsed"/>']['group'] = '<xsl:value-of select="./void[@property='group']/string"/>'
        <xsl:call-template name="properties"><xsl:with-param name="profile" select="$profile_parsed"/></xsl:call-template>
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
