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

<xsl:template name="profiles">
    <xsl:for-each select="/java/object/void[@method='add']/object[@class='workbench.db.ConnectionProfile']">
        <xsl:variable name="profile">
            <xsl:choose>
                <xsl:when test="not(./void[@property='group']/string)"><xsl:value-of select="./void[@property='name']/string"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="./void[@property='group']/string"/>\<xsl:value-of select="./void[@property='name']/string"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        let b:profiles['<xsl:value-of select="$profile"/>'] = {}
        let b:profiles['<xsl:value-of select="$profile"/>']['name'] = '<xsl:value-of select="$profile"/>'
        let b:profiles['<xsl:value-of select="$profile"/>']['type'] = '<xsl:value-of select="./void[@property='driverName']/string"/>'
        let b:profiles['<xsl:value-of select="$profile"/>']['group'] = '<xsl:value-of select="./void[@property='group']/string"/>'
        <xsl:call-template name="properties"><xsl:with-param name="profile" select="$profile"/></xsl:call-template>
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
