<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:transform
     version="1.0"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>
<xsl:output
  encoding="iso-8859-15"
  method="text"
  omit-xml-declaration="yes"
  doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"
/>

<xsl:template match="/">
<xsl:call-template name="table-definitions"/>
<xsl:call-template name="view-definitions"/>
</xsl:template>

<xsl:template name="table-definitions">
    <xsl:for-each select="/schema-report/table-def">
        let b:autocomplete_tables['T#<xsl:value-of select="@name"/>'] = [<xsl:for-each select="column-def">'<xsl:value-of select="@name"/>',</xsl:for-each>]
    </xsl:for-each>
</xsl:template>

<xsl:template name="view-definitions">
    <xsl:for-each select="/schema-report/view-def">
        let b:autocomplete_tables['V#<xsl:value-of select="@name"/>'] = [<xsl:for-each select="column-def">'<xsl:value-of select="@name"/>',</xsl:for-each>]
    </xsl:for-each>
</xsl:template>


</xsl:transform>
